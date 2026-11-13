import 'dart:math' as math;

class PosturePerformanceConfig {
  const PosturePerformanceConfig({
    this.analysisInterval = const Duration(milliseconds: 300),
    this.maximumInferenceDimension = 320,
  });

  /// Posture is deliberately lower priority than preview/audio smoothness.
  /// 300 ms means at most about 3.3 pose requests per second. The frame gate
  /// still allows only one request at a time and drops frames while native
  /// inference is busy, so slower devices cannot build up a stale queue.
  final Duration analysisInterval;

  /// YUV is converted directly into this aspect-ratio-preserving bound. This
  /// affects only MediaPipe input; the visible camera preview stays high-res.
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
