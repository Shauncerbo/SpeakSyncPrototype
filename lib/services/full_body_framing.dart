import 'posture_analysis.dart';

enum FullBodyFramingState { detected, moveFarther, unavailable }

String fullBodyFramingLabel(FullBodyFramingState state) => switch (state) {
  FullBodyFramingState.detected => 'Full body detected',
  FullBodyFramingState.moveFarther => 'Move farther away',
  FullBodyFramingState.unavailable => 'Position yourself in view',
};

/// Experimental visibility check for the optional full-body preview.
///
/// This deliberately does not classify posture and does not feed any score.
/// Thresholds are provisional and require physical-device calibration.
class FullBodyFramingAnalyzer {
  const FullBodyFramingAnalyzer({
    this.minimumUpperBodyVisibility = .55,
    this.minimumLowerBodyVisibility = .45,
    this.frameMargin = .015,
  });

  final double minimumUpperBodyVisibility;
  final double minimumLowerBodyVisibility;
  final double frameMargin;

  FullBodyFramingState analyze(PoseFrameLandmarks? landmarks) {
    final points = landmarks?.allPoints ?? const <PoseLandmarkPoint>[];
    if (points.length < 33) return FullBodyFramingState.unavailable;

    // Nose, shoulders and hips establish that a person is detected before a
    // missing leg/foot is interpreted as a request to move farther away.
    const upperIndexes = [0, 11, 12, 23, 24];
    if (!_visible(points, upperIndexes, minimumUpperBodyVisibility)) {
      return FullBodyFramingState.unavailable;
    }

    // Knees, ankles and foot tips are required only for experimental
    // full-body framing. Their values never alter the posture measurement.
    const lowerIndexes = [25, 26, 27, 28, 31, 32];
    if (!_visible(points, lowerIndexes, minimumLowerBodyVisibility) ||
        !_insideFrame(points, [...upperIndexes, ...lowerIndexes])) {
      return FullBodyFramingState.moveFarther;
    }
    return FullBodyFramingState.detected;
  }

  bool _visible(
    List<PoseLandmarkPoint> points,
    List<int> indexes,
    double minimumVisibility,
  ) => indexes.every((index) {
    final point = points[index];
    return point.isFinite && point.visibility >= minimumVisibility;
  });

  bool _insideFrame(List<PoseLandmarkPoint> points, List<int> indexes) =>
      indexes.every((index) {
        final point = points[index];
        return point.x >= frameMargin &&
            point.x <= 1 - frameMargin &&
            point.y >= frameMargin &&
            point.y <= 1 - frameMargin;
      });
}
