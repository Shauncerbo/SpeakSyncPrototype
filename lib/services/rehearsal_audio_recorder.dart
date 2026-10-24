import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'speech_audio_config.dart';
import 'wav_audio.dart';

class AudioRecordingException implements Exception {
  const AudioRecordingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RehearsalAudioRecorder {
  static const defaultLiveChunkDuration = Duration(seconds: 10);
  static const defaultLiveChunkOverlap = Duration(milliseconds: 750);

  RehearsalAudioRecorder({
    AudioRecorder? recorder,
    Future<Directory> Function()? temporaryDirectory,
    this.chunkDuration = defaultLiveChunkDuration,
    this.liveChunkOverlap = defaultLiveChunkOverlap,
  }) : assert(chunkDuration > Duration.zero),
       assert(liveChunkOverlap >= Duration.zero),
       assert(liveChunkOverlap < chunkDuration),
       _recorder = recorder ?? AudioRecorder(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final AudioRecorder _recorder;
  final Future<Directory> Function() _temporaryDirectory;
  final Duration chunkDuration;
  final Duration liveChunkOverlap;
  final _chunks = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get chunks => _chunks.stream;
  StreamSubscription<Uint8List>? _pcmSubscription;
  Completer<void>? _pcmFinished;
  IOSink? _pcmSink;
  BytesBuilder _chunkBuffer = BytesBuilder(copy: true);
  Uint8List _previousChunkTail = Uint8List(0);
  String? _pcmPath;
  int _pcmBytes = 0;
  bool _streamMode = false;
  Object? _pcmError;
  int? _pendingPcmByte;
  Pcm16SignalAnalyzer _signalAnalyzer = Pcm16SignalAnalyzer();
  String? _recordingPath;
  bool _started = false;

  Pcm16SignalSummary? _lastCaptureQuality;

  Pcm16SignalSummary? get lastCaptureQuality => _lastCaptureQuality;

  bool get hasStarted => _started;

  /// Current input volume from the same recorder used for transcription.
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((amplitude) => levelFromDecibels(amplitude.current));

  static double levelFromDecibels(double decibels) {
    // Suppress quiet room noise; this measures volume, not speech recognition.
    if (!decibels.isFinite || decibels <= -50) return 0;
    return ((decibels + 50) / 40).clamp(0.0, 1.0);
  }

  Future<void> start({bool enableLiveChunks = false}) async {
    if (_started) return;
    if (!await _recorder.hasPermission()) {
      throw const AudioRecordingException(
        'Microphone permission is required to transcribe the rehearsal.',
      );
    }

    try {
      final directory = await _temporaryDirectory();
      final path =
          '${directory.path}${Platform.pathSeparator}'
          'speaksync-${DateTime.now().microsecondsSinceEpoch}.m4a';
      if (enableLiveChunks) {
        try {
          final pcmPath = path.replaceFirst(RegExp(r'\.m4a$'), '.pcm');
          final stream = await _recorder.startStream(SpeechAudioConfig.pcm16);
          _pcmPath = pcmPath;
          _pcmSink = File(pcmPath).openWrite();
          _pcmFinished = Completer<void>();
          _pcmBytes = 0;
          _pcmError = null;
          _pendingPcmByte = null;
          _signalAnalyzer = Pcm16SignalAnalyzer();
          _lastCaptureQuality = null;
          _chunkBuffer = BytesBuilder(copy: true);
          _previousChunkTail = Uint8List(0);
          _streamMode = true;
          _pcmSubscription = stream.listen(
            _onPcmData,
            onError: (Object error) {
              _pcmError = error;
              if (!_pcmFinished!.isCompleted) _pcmFinished!.complete();
            },
            onDone: () {
              if (!_pcmFinished!.isCompleted) _pcmFinished!.complete();
            },
          );
          _started = true;
          return;
        } catch (_) {
          // Keep a full recording even when PCM streaming is unavailable.
          try {
            await _recorder.stop();
          } catch (_) {}
          await _pcmSubscription?.cancel();
          await _pcmSink?.close();
          await deleteTemporaryFile(_pcmPath);
          _pcmSubscription = null;
          _pcmSink = null;
          _pcmPath = null;
          _streamMode = false;
        }
      }
      _lastCaptureQuality = null;
      await _recorder.start(SpeechAudioConfig.aac, path: path);
      _recordingPath = path;
      _started = true;
    } catch (_) {
      throw const AudioRecordingException(
        'SpeakSync could not start microphone recording.',
      );
    }
  }

  void _onPcmData(Uint8List bytes) {
    if (_pcmError != null || bytes.isEmpty) return;
    final alignedBytes = _completePcmSamples(bytes);
    if (alignedBytes.isEmpty) return;
    try {
      _pcmSink?.add(alignedBytes);
    } catch (error) {
      _pcmError = error;
      if (_pcmFinished != null && !_pcmFinished!.isCompleted) {
        _pcmFinished!.complete();
      }
      return;
    }
    _pcmBytes += alignedBytes.length;
    _signalAnalyzer.addBytes(alignedBytes);
    final chunkSize =
        chunkDuration.inMicroseconds *
        WavAudio.bytesPerSecond ~/
        Duration.microsecondsPerSecond;
    // PCM can arrive before the screen subscribes; include those early samples
    // in the first live chunk while always writing the full recording.
    if (chunkSize <= 0) return;
    var offset = 0;
    while (offset < alignedBytes.length) {
      final take = (chunkSize - _chunkBuffer.length).clamp(
        0,
        alignedBytes.length - offset,
      );
      if (take == 0) break;
      _chunkBuffer.add(
        Uint8List.sublistView(alignedBytes, offset, offset + take),
      );
      offset += take;
      if (_chunkBuffer.length == chunkSize) {
        final freshChunk = _chunkBuffer.takeBytes();
        final liveChunk =
            Uint8List(_previousChunkTail.length + freshChunk.length)
              ..setRange(0, _previousChunkTail.length, _previousChunkTail)
              ..setRange(
                _previousChunkTail.length,
                _previousChunkTail.length + freshChunk.length,
                freshChunk,
              );
        _chunks.add(liveChunk);

        // Carry a small amount of already-recorded PCM into the next live WAV
        // so Whisper can hear words that straddle a ten-second boundary. The
        // full-recording sink above still receives every sample exactly once.
        final overlapBytes =
            liveChunkOverlap.inMicroseconds *
            WavAudio.bytesPerSecond ~/
            Duration.microsecondsPerSecond;
        final retainedBytes = overlapBytes.clamp(0, freshChunk.length);
        _previousChunkTail = retainedBytes == 0
            ? Uint8List(0)
            : Uint8List.fromList(
                freshChunk.sublist(freshChunk.length - retainedBytes),
              );
      }
    }
  }

  Uint8List _completePcmSamples(Uint8List bytes) {
    final pending = _pendingPcmByte;
    if (pending == null && bytes.length.isEven) return bytes;

    final combined = Uint8List(bytes.length + (pending == null ? 0 : 1));
    var offset = 0;
    if (pending != null) {
      combined[0] = pending;
      offset = 1;
    }
    combined.setRange(offset, combined.length, bytes);
    _pendingPcmByte = combined.length.isOdd ? combined.last : null;
    final completeLength = combined.length - (combined.length.isOdd ? 1 : 0);
    return completeLength == 0
        ? Uint8List(0)
        : Uint8List.sublistView(combined, 0, completeLength);
  }

  Future<void> pause() async {
    if (!_started) return;
    await _recorder.pause();
  }

  Future<void> resume() async {
    if (!_started) return;
    await _recorder.resume();
  }

  Future<String?> stop() async {
    if (!_started) return null;
    try {
      if (_streamMode) {
        await _recorder.stop();
        await _pcmFinished?.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
        await _pcmSubscription?.cancel();
        await _pcmSink?.close();
        _pcmSink = null;
        _previousChunkTail = Uint8List(0);
        _lastCaptureQuality = _signalAnalyzer.summary;
        if (_pcmError != null || _pendingPcmByte != null || _pcmBytes == 0) {
          throw const AudioRecordingException(
            'No rehearsal audio was recorded.',
          );
        }
        final source = _pcmPath!;
        final path = source.replaceFirst(RegExp(r'\.pcm$'), '.wav');
        try {
          await WavAudio.wrapPcmFile(source, path, _pcmBytes);
          _recordingPath = path;
          _started = false;
          _streamMode = false;
          return path;
        } finally {
          await deleteTemporaryFile(source);
          _pcmPath = null;
        }
      }
      final path = await _recorder.stop();
      _started = false;
      return path ?? _recordingPath;
    } catch (_) {
      _started = false;
      await _pcmSubscription?.cancel();
      await _pcmSink?.close();
      _pcmSink = null;
      _previousChunkTail = Uint8List(0);
      _pendingPcmByte = null;
      await deleteTemporaryFile(_pcmPath);
      _pcmPath = null;
      _streamMode = false;
      throw const AudioRecordingException(
        'SpeakSync could not finish the microphone recording.',
      );
    }
  }

  Future<void> cancel() async {
    if (!_started) return;
    try {
      await _recorder.cancel();
    } finally {
      _started = false;
      await _pcmSubscription?.cancel();
      await _pcmSink?.close();
      _pcmSink = null;
      _previousChunkTail = Uint8List(0);
      _pendingPcmByte = null;
      await deleteTemporaryFile(_pcmPath);
      _pcmPath = null;
      _streamMode = false;
      await deleteTemporaryFile(_recordingPath);
    }
  }

  /// Wait for native recording shutdown before another recording is started.
  /// Android's cancel acknowledgement can precede encoder/thread shutdown.
  Future<void> discard() async {
    final path = await stop();
    await deleteTemporaryFile(path);
    _recordingPath = null;
  }

  Future<void> deleteTemporaryFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Temporary files are also managed by the operating system cache.
    }
  }

  Future<void> dispose() async {
    await _pcmSubscription?.cancel();
    await _pcmSink?.close();
    _previousChunkTail = Uint8List(0);
    _pendingPcmByte = null;
    await deleteTemporaryFile(_pcmPath);
    await _chunks.close();
    await _recorder.dispose();
  }
}
