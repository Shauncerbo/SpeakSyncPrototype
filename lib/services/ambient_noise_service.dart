import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'speech_audio_config.dart';

enum AmbientNoiseLevel { quiet, moderate, noisy }

/// Prototype thresholds, NOT scientifically validated. Calibrate using
/// real-device testing; microphone gain and processing vary between phones.
/// RMS is normalized to full-scale PCM, not a calibrated sound-pressure level.
class AmbientNoiseConfig {
  const AmbientNoiseConfig({
    this.quietBelow = 0.01,
    this.noisyAtOrAbove = 0.05,
    this.sampleDuration = const Duration(milliseconds: 2500),
    this.refreshDelay = const Duration(milliseconds: 500),
    this.errorRetryDelay = const Duration(seconds: 5),
  }) : assert(quietBelow > 0),
       assert(noisyAtOrAbove > quietBelow),
       assert(noisyAtOrAbove <= 1);

  final double quietBelow;
  final double noisyAtOrAbove;
  final Duration sampleDuration;
  final Duration refreshDelay;
  final Duration errorRetryDelay;

  AmbientNoiseLevel classify(double rms) {
    if (!rms.isFinite || rms < 0 || rms > 1) {
      throw ArgumentError.value(
        rms,
        'rms',
        'Expected normalized RMS in [0, 1]',
      );
    }
    if (rms < quietBelow) return AmbientNoiseLevel.quiet;
    if (rms < noisyAtOrAbove) return AmbientNoiseLevel.moderate;
    return AmbientNoiseLevel.noisy;
  }
}

/// Streaming signed little-endian PCM16 RMS: sqrt(sum((sample/32768)^2)/N).
/// Retains only energy, count and an optional split byte, never recorded audio.
class Pcm16Rms {
  double _squaredSum = 0;
  int sampleCount = 0;
  int? _lowByte;

  void addBytes(Uint8List bytes) {
    for (final byte in bytes) {
      if (_lowByte == null) {
        _lowByte = byte;
      } else {
        final unsigned = _lowByte! | (byte << 8);
        final signed = unsigned >= 32768 ? unsigned - 65536 : unsigned;
        final normalized = signed / 32768;
        _squaredSum += normalized * normalized;
        sampleCount++;
        _lowByte = null;
      }
    }
  }

  // No samples is unavailable, not a quiet room.
  double? get rms =>
      sampleCount == 0 ? null : math.sqrt(_squaredSum / sampleCount);
}

class AmbientNoiseResult {
  const AmbientNoiseResult({required this.level, required this.rms})
    : message = null;
  const AmbientNoiseResult.unavailable(this.message) : level = null, rms = null;

  final AmbientNoiseLevel? level;
  final double? rms;
  final String? message;
}

abstract interface class AmbientNoiseInput {
  Future<Stream<Uint8List>> start();
  Future<void> close();
}

class _MicrophoneNoiseInput implements AmbientNoiseInput {
  _MicrophoneNoiseInput({required this.requestPermission});

  final bool requestPermission;
  AudioRecorder? _recorder;

  @override
  Future<Stream<Uint8List>> start() async {
    var permission = await Permission.microphone.status;
    if (!permission.isGranted && requestPermission) {
      permission = await Permission.microphone.request();
    }
    if (!permission.isGranted) {
      throw const _NoisePermissionDenied();
    }
    final recorder = _recorder = AudioRecorder();
    return recorder.startStream(SpeechAudioConfig.pcm16);
  }

  @override
  Future<void> close() async {
    final recorder = _recorder;
    if (recorder == null) return;
    try {
      await recorder.stop();
    } finally {
      await recorder.dispose();
      _recorder = null;
    }
  }
}

class _NoisePermissionDenied implements Exception {
  const _NoisePermissionDenied();
}

class AmbientNoiseService {
  AmbientNoiseService({
    this.config = const AmbientNoiseConfig(),
    AmbientNoiseInput Function()? inputFactory,
  }) : _inputFactory = inputFactory;

  final AmbientNoiseConfig config;
  final AmbientNoiseInput Function()? _inputFactory;
  Future<AmbientNoiseResult>? _active;
  Completer<void>? _cancel;
  bool _disposed = false;
  bool _permissionRequested = false;

  Future<AmbientNoiseResult> check() {
    if (_disposed) {
      return Future.value(
        const AmbientNoiseResult.unavailable('Noise check unavailable.'),
      );
    }
    if (_active != null) return _active!;
    final cancel = _cancel = Completer<void>();
    return _active = _sample(cancel).whenComplete(() {
      _active = null;
      _cancel = null;
    });
  }

  Future<AmbientNoiseResult> _sample(Completer<void> cancel) async {
    AmbientNoiseInput? input;
    StreamSubscription<Uint8List>? subscription;
    Timer? timer;
    var result = const AmbientNoiseResult.unavailable(
      'Noise check paused. You can continue.',
    );
    try {
      // Automatic refresh must not repeatedly open permission dialogs.
      final requestPermission = !_permissionRequested;
      _permissionRequested = true;
      input =
          _inputFactory?.call() ??
          _MicrophoneNoiseInput(requestPermission: requestPermission);
      final stream = await input.start();
      if (!cancel.isCompleted) {
        final rms = Pcm16Rms();
        final finished = Completer<void>();
        var failed = false;
        void fail() {
          failed = true;
          if (!finished.isCompleted) finished.complete();
        }

        subscription = stream.listen(
          rms.addBytes,
          onError: (Object _) => fail(),
          onDone: fail,
        );
        timer = Timer(config.sampleDuration, () {
          if (!finished.isCompleted) finished.complete();
        });
        await Future.any([finished.future, cancel.future]);
        final value = rms.rms;
        if (!cancel.isCompleted) {
          // Require at least 0.5 seconds of PCM at the requested 16 kHz.
          result = failed || value == null || rms.sampleCount < 8000
              ? const AmbientNoiseResult.unavailable(
                  'No usable microphone input. Check microphone access; retrying automatically.',
                )
              : AmbientNoiseResult(level: config.classify(value), rms: value);
        }
      }
    } on _NoisePermissionDenied {
      result = const AmbientNoiseResult.unavailable(
        'Microphone permission needed. Allow it in Settings; checking resumes automatically.',
      );
    } catch (_) {
      result = const AmbientNoiseResult.unavailable(
        'Microphone unavailable. Check permission or close other recording apps.',
      );
    } finally {
      timer?.cancel();
      try {
        await subscription?.cancel();
      } catch (_) {
        // Still release the native microphone if stream cleanup fails.
      }
      try {
        await input?.close();
      } catch (_) {
        result = const AmbientNoiseResult.unavailable(
          'Microphone check could not finish. Retrying automatically.',
        );
      }
    }
    return result;
  }

  /// Waits for native startup/shutdown, preventing overlapping recorders.
  Future<void> stop() async {
    if (_cancel != null && !_cancel!.isCompleted) _cancel!.complete();
    await _active;
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}
