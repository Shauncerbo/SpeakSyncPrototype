import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/posture_performance.dart';

void main() {
  test('pose gate throttles results to two FPS by default', () {
    final gate = PoseFrameGate(
      minimumInterval: const PosturePerformanceConfig().analysisInterval,
    );

    expect(gate.tryAcquire(Duration.zero), isTrue);
    gate.complete();
    expect(gate.tryAcquire(const Duration(milliseconds: 300)), isFalse);
    expect(gate.tryAcquire(const Duration(milliseconds: 500)), isTrue);
    gate.complete();
    expect(gate.skippedFrames, 1);
  });

  test('pose gate drops frames while inference is busy and never queues', () {
    final gate = PoseFrameGate(
      minimumInterval: const Duration(milliseconds: 500),
    );

    expect(gate.tryAcquire(Duration.zero), isTrue);
    expect(gate.tryAcquire(const Duration(seconds: 1)), isFalse);
    expect(gate.isBusy, isTrue);
    expect(gate.skippedFrames, 1);
    gate.complete();
    expect(gate.tryAcquire(const Duration(seconds: 1)), isTrue);
  });

  test('pose gate reset clears busy, throttle, and skipped state', () {
    final gate = PoseFrameGate(
      minimumInterval: const Duration(milliseconds: 500),
    );
    gate.tryAcquire(Duration.zero);
    gate.tryAcquire(const Duration(milliseconds: 10));

    gate.reset();

    expect(gate.isBusy, isFalse);
    expect(gate.skippedFrames, 0);
    expect(gate.tryAcquire(Duration.zero), isTrue);
  });

  test('inference dimension is constrained to a safe configurable range', () {
    expect(boundedInferenceDimension(64), 128);
    expect(boundedInferenceDimension(384), 384);
    expect(boundedInferenceDimension(1000), 640);
  });

  test('diagnostics calculates average time and a periodic summary', () {
    final diagnostics = PosePerformanceDiagnostics();
    diagnostics.recordProcessed(
      processingDuration: const Duration(milliseconds: 50),
      conversionDuration: const Duration(milliseconds: 10),
      inferenceDuration: const Duration(milliseconds: 40),
    );
    diagnostics.recordProcessed(
      processingDuration: const Duration(milliseconds: 70),
      conversionDuration: const Duration(milliseconds: 10),
      inferenceDuration: const Duration(milliseconds: 60),
    );

    expect(diagnostics.averageProcessingMilliseconds, 60);
    expect(diagnostics.averageConversionMilliseconds, 10);
    expect(diagnostics.averageInferenceMilliseconds, 50);
    expect(diagnostics.summary(skippedFrames: 4), contains('50ms'));
    expect(diagnostics.summary(skippedFrames: 4), contains('skipped frames 4'));
  });
}
