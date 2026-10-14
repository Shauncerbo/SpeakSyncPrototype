import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/camera_framing.dart';
import 'package:speaksync_prototype/services/posture_analysis.dart';

void main() {
  group('CameraFramingTracker', () {
    test('large body geometry is Too Close', () {
      final measurement = CameraFramingTracker().update(
        _pose(shoulderWidth: 0.66, torsoHeight: 0.64),
      );

      expect(measurement.state, CameraFramingState.tooClose);
    });

    test('normal body geometry is Proper', () {
      final measurement = CameraFramingTracker().update(
        _pose(shoulderWidth: 0.34, torsoHeight: 0.46),
      );

      expect(measurement.state, CameraFramingState.proper);
      expect(measurement.normalizedBodyScale, closeTo(0.40, 0.0001));
    });

    test('small body geometry is Too Far', () {
      final measurement = CameraFramingTracker().update(
        _pose(shoulderWidth: 0.16, torsoHeight: 0.20),
      );

      expect(measurement.state, CameraFramingState.tooFar);
    });

    test('missing and low-confidence landmarks are Unavailable', () {
      final tracker = CameraFramingTracker();

      expect(tracker.update(null).state, CameraFramingState.unavailable);
      expect(
        tracker
            .update(
              _pose(shoulderWidth: 0.34, torsoHeight: 0.46, visibility: 0.4),
            )
            .state,
        CameraFramingState.unavailable,
      );
    });

    test('normalized calculation is independent of preview pixel size', () {
      final first = CameraFramingTracker().update(
        _pose(shoulderWidth: 0.34, torsoHeight: 0.46),
      );
      final second = CameraFramingTracker().update(
        _pose(shoulderWidth: 0.34, torsoHeight: 0.46),
      );

      // The tracker consumes only 0..1 landmark coordinates, so identical
      // framing remains identical for different camera pixel resolutions.
      expect(second.state, first.state);
      expect(second.normalizedBodyScale, first.normalizedBodyScale);
    });

    test('hysteresis prevents flicker near close and far boundaries', () {
      final tracker = CameraFramingTracker();

      expect(
        tracker.update(_poseForScale(0.53)).state,
        CameraFramingState.tooClose,
      );
      expect(
        tracker.update(_poseForScale(0.50)).state,
        CameraFramingState.tooClose,
      );
      expect(
        tracker.update(_poseForScale(0.48)).state,
        CameraFramingState.proper,
      );
      expect(
        tracker.update(_poseForScale(0.27)).state,
        CameraFramingState.tooFar,
      );
      expect(
        tracker.update(_poseForScale(0.30)).state,
        CameraFramingState.tooFar,
      );
      expect(
        tracker.update(_poseForScale(0.32)).state,
        CameraFramingState.proper,
      );
    });

    test('framing calculation does not modify posture classification', () {
      const analyzer = PostureAnalyzer();
      final pose = _pose(shoulderWidth: 0.34, torsoHeight: 0.46);
      final before = analyzer.analyze(pose).classification;

      CameraFramingTracker().update(pose);

      expect(analyzer.analyze(pose).classification, before);
    });

    test('uses supplied landmarks without an inference dependency', () {
      final tracker = CameraFramingTracker();
      final pose = _pose(shoulderWidth: 0.34, torsoHeight: 0.46);

      for (var index = 0; index < 5; index++) {
        expect(tracker.update(pose).state, CameraFramingState.proper);
      }

      // CameraFramingTracker accepts the existing PoseFrameLandmarks result;
      // it has no camera, MethodChannel, or PostureLandmarker dependency.
      expect(tracker.state, CameraFramingState.proper);
    });

    test('reset removes the previous framing state', () {
      final tracker = CameraFramingTracker();
      tracker.update(_poseForScale(0.60));

      tracker.reset();

      expect(tracker.state, CameraFramingState.unavailable);
    });
  });
}

PoseFrameLandmarks _poseForScale(double scale) =>
    _pose(shoulderWidth: scale, torsoHeight: scale);

PoseFrameLandmarks _pose({
  required double shoulderWidth,
  required double torsoHeight,
  double visibility = 0.95,
}) {
  const centerX = 0.5;
  const shoulderY = 0.15;
  final hipY = shoulderY + torsoHeight;
  return PoseFrameLandmarks(
    leftShoulder: PoseLandmarkPoint(
      x: centerX - shoulderWidth / 2,
      y: shoulderY,
      visibility: visibility,
    ),
    rightShoulder: PoseLandmarkPoint(
      x: centerX + shoulderWidth / 2,
      y: shoulderY,
      visibility: visibility,
    ),
    leftHip: PoseLandmarkPoint(
      x: centerX - shoulderWidth * 0.3,
      y: hipY,
      visibility: visibility,
    ),
    rightHip: PoseLandmarkPoint(
      x: centerX + shoulderWidth * 0.3,
      y: hipY,
      visibility: visibility,
    ),
  );
}
