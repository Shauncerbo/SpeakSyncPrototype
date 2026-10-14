import 'dart:math' as math;

class PosturePerformanceConfig {
  const PosturePerformanceConfig({
    this.analysisInterval = const Duration(milliseconds: 500),
    this.maximumInferenceDimension = 384,
  });

  /// Posture is deliberately lower priority than preview/audio smoothness.
  /// 500 ms means at most two pose requests per second.
  final Duration analysisInterval;

  /// YUV is converted directly into this aspect-ratio-preserving bound.
  final int maximumInferenceDimension;
}

class PoseFrameGate {
  PoseFrameGate({required this.minimumInterval});

  final Duration minimumInterval;
  Duration? _lastAcceptedAt;
  bool _busy = false;
  int _skippedFrames = 0;

  bool get isBusy => _busy;
  int get skippedFrames => _skippedFrames;

  bool tryAcquire(Duration timestamp) {
    if (_busy) {
      _skippedFrames++;
      return false;
    }
    final previous = _lastAcceptedAt;
    if (previous != null && timestamp - previous < minimumInterval) {
      _skippedFrames++;
      return false;
    }
    _busy = true;
    _lastAcceptedAt = timestamp;
    return true;
  }

  void complete() => _busy = false;

  void reset() {
    _lastAcceptedAt = null;
    _busy = false;
    _skippedFrames = 0;
  }
}

class PosePerformanceDiagnostics {
  final Stopwatch _window = Stopwatch();
  int _processedFrames = 0;
  double _totalProcessingMilliseconds = 0;
  double _totalConversionMilliseconds = 0;
  double _totalInferenceMilliseconds = 0;

  int get processedFrames => _processedFrames;

  double get averageProcessingMilliseconds => _processedFrames == 0
      ? 0
      : _totalProcessingMilliseconds / _processedFrames;

  double get averageConversionMilliseconds => _processedFrames == 0
      ? 0
      : _totalConversionMilliseconds / _processedFrames;

  double get averageInferenceMilliseconds => _processedFrames == 0
      ? 0
      : _totalInferenceMilliseconds / _processedFrames;

  double get processedFramesPerSecond {
    final seconds =
        _window.elapsedMicroseconds / Duration.microsecondsPerSecond;
    return seconds <= 0 ? 0 : _processedFrames / seconds;
  }

  void start() {
    if (!_window.isRunning) _window.start();
  }

  void recordProcessed({
    required Duration processingDuration,
    required Duration conversionDuration,
    required Duration inferenceDuration,
  }) {
    start();
    _processedFrames++;
    _totalProcessingMilliseconds += processingDuration.inMicroseconds / 1000;
    _totalConversionMilliseconds += conversionDuration.inMicroseconds / 1000;
    _totalInferenceMilliseconds += inferenceDuration.inMicroseconds / 1000;
  }

  String summary({required int skippedFrames}) {
    final inferenceAverage = averageInferenceMilliseconds.round();
    final conversionAverage = averageConversionMilliseconds.round();
    final fps = processedFramesPerSecond.toStringAsFixed(1);
    return 'Pose: inference avg ${inferenceAverage}ms, '
        'conversion avg ${conversionAverage}ms, processed $fps FPS, '
        'skipped frames $skippedFrames';
  }

  void reset() {
    _window
      ..stop()
      ..reset();
    _processedFrames = 0;
    _totalProcessingMilliseconds = 0;
    _totalConversionMilliseconds = 0;
    _totalInferenceMilliseconds = 0;
  }
}

int boundedInferenceDimension(int requested) =>
    math.max(128, math.min(640, requested));
