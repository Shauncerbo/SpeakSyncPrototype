import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/ambient_noise_service.dart';

Uint8List pcm(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

class _Input implements AmbientNoiseInput {
  final stream = StreamController<Uint8List>();
  final started = Completer<void>();
  Completer<void>? gate;
  bool fail = false;
  bool closed = false;

  @override
  Future<Stream<Uint8List>> start() async {
    started.complete();
    await gate?.future;
    if (fail) throw StateError('Input unavailable or permission denied');
    return stream.stream;
  }

  @override
  Future<void> close() async {
    closed = true;
    // Do not wait on an unlistened single-subscription stream in failure cases.
    unawaited(stream.close());
  }
}

void main() {
  const config = AmbientNoiseConfig();
  test('No PCM is unavailable, silence is zero RMS', () {
    final rms = Pcm16Rms();
    expect(rms.rms, isNull);
    rms.addBytes(pcm([0, 0, 0]));
    expect(rms.rms, 0);
    expect(config.classify(rms.rms!), AmbientNoiseLevel.quiet);
  });

  test('RMS uses signed samples and sample-weighted energy, not peaks', () {
    final rms = Pcm16Rms()..addBytes(pcm([-32768, 0, 16384, 0]));
    expect(rms.rms, closeTo(math.sqrt(1.25 / 4), 1e-12));
  });

  test('Odd byte chunk boundaries preserve samples', () {
    final bytes = pcm([-32768, 32767, 1000, -1000]);
    final rms = Pcm16Rms();
    for (final byte in bytes) {
      rms.addBytes(Uint8List.fromList([byte]));
    }
    final whole = Pcm16Rms()..addBytes(bytes);
    expect(rms.sampleCount, 4);
    expect(rms.rms, whole.rms);
  });

  for (final entry in {
    1: AmbientNoiseLevel.quiet,
    100: AmbientNoiseLevel.quiet,
    1000: AmbientNoiseLevel.moderate,
    5000: AmbientNoiseLevel.noisy,
    32767: AmbientNoiseLevel.noisy,
  }.entries) {
    test('PCM amplitude ${entry.key} classifies ${entry.value.name}', () {
      final rms = Pcm16Rms()..addBytes(pcm([entry.key, -entry.key]));
      expect(rms.rms, closeTo(entry.key / 32768, 1e-12));
      expect(config.classify(rms.rms!), entry.value);
    });
  }

  test('Threshold boundaries and custom thresholds are explicit', () {
    expect(config.classify(0.00999), AmbientNoiseLevel.quiet);
    expect(config.classify(0.01), AmbientNoiseLevel.moderate);
    expect(config.classify(0.04999), AmbientNoiseLevel.moderate);
    expect(config.classify(0.05), AmbientNoiseLevel.noisy);
    expect(config.classify(1), AmbientNoiseLevel.noisy);
    expect(
      const AmbientNoiseConfig(
        quietBelow: 0.1,
        noisyAtOrAbove: 0.2,
      ).classify(0.05),
      AmbientNoiseLevel.quiet,
    );
    for (final invalid in [double.nan, double.infinity, -0.1, 2.0]) {
      expect(() => config.classify(invalid), throwsArgumentError);
    }
  });

  test(
    '2.5 second check releases input and returns whole-window RMS',
    () async {
      final input = _Input();
      final service = AmbientNoiseService(inputFactory: () => input);
      final future = service.check();
      await input.started.future;
      input.stream.add(pcm(List.filled(40000, 1000)));
      final result = await future;
      expect(result.level, AmbientNoiseLevel.moderate);
      expect(result.rms, closeTo(1000 / 32768, 1e-10));
      expect(input.closed, isTrue);
      await service.dispose();
    },
  );

  for (final mode in ['empty', 'short', 'error', 'ended', 'permission']) {
    test('$mode input is unavailable and releases microphone', () async {
      final input = _Input()..fail = mode == 'permission';
      final service = AmbientNoiseService(
        config: const AmbientNoiseConfig(
          sampleDuration: Duration(milliseconds: 20),
        ),
        inputFactory: () => input,
      );
      final future = service.check();
      await input.started.future;
      if (mode == 'short') input.stream.add(pcm([0]));
      if (mode == 'error') input.stream.addError(StateError('lost mic'));
      if (mode == 'ended') unawaited(input.stream.close());
      expect((await future).level, isNull);
      expect(input.closed, isTrue);
      await service.dispose();
    });
  }

  test(
    'Cancel waits for pending startup, closes it, and never calls it quiet',
    () async {
      final input = _Input()..gate = Completer<void>();
      final service = AmbientNoiseService(inputFactory: () => input);
      final future = service.check();
      expect(identical(service.check(), future), isTrue);
      await input.started.future;
      var stopped = false;
      final stop = service.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      input.gate!.complete();
      await stop;
      expect(input.closed, isTrue);
      expect((await future).level, isNull);
      await service.dispose();
      expect((await service.check()).level, isNull);
    },
  );
}
