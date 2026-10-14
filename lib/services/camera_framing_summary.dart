import 'camera_framing.dart';

/// Tracks existing classifications only; no new distance or scoring thresholds.
class CameraFramingSummaryTracker {
  CameraFramingSummaryTracker({required this.maximumSampleGap});
  final Duration maximumSampleGap;
  final Map<String, int> _milliseconds = {
    'tooClose': 0,
    'proper': 0,
    'tooFar': 0,
  };
  Duration? _previousTime;
  CameraFramingState? _previousState;

  void addFrame(CameraFramingState state, Duration timestamp) {
    if (state == CameraFramingState.unavailable) {
      interrupt();
      return;
    }
    final previous = _previousTime;
    if (previous != null && timestamp <= previous) {
      interrupt();
      return;
    }
    if (previous != null && _previousState != null) {
      final gap = timestamp - previous;
      if (gap > Duration.zero && gap <= maximumSampleGap) {
        final key = _previousState!.name;
        _milliseconds[key] = _milliseconds[key]! + gap.inMilliseconds;
      }
    }
    _previousTime = timestamp;
    _previousState = state;
  }

  Map<String, int> get milliseconds => Map.unmodifiable(_milliseconds);
  void interrupt() {
    _previousTime = null;
    _previousState = null;
  }

  void reset() {
    interrupt();
    _milliseconds.updateAll((key, value) => 0);
  }
}
