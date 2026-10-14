import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/posture_analysis.dart';
import 'package:speaksync_prototype/services/posture_landmarker_service.dart';

void main() {
  const analyzer = PostureAnalyzer();

  group('PostureAnalyzer', () {
    test('accepts level shoulders and an upright torso', () {
      final result = analyzer.analyze(_pose());

      expect(result.classification, PostureFrameClassification.acceptable);
      expect(result.shoulderTiltDegrees, closeTo(0, 0.01));
      expect(result.torsoLeanDegrees, closeTo(0, 0.01));
    });

    test('flags shoulder tilt beyond the prototype threshold', () {
      final result = analyzer.analyze(
        _pose(
          leftShoulder: const PoseLandmarkPoint(
            x: 0.35,
            y: 0.25,
            visibility: 0.95,
          ),
          rightShoulder: const PoseLandmarkPoint(
            x: 0.65,
            y: 0.36,
            visibility: 0.95,
          ),
        ),
      );

      expect(result.classification, PostureFrameClassification.needsAdjustment);
      expect(result.shoulderTiltDegrees, greaterThan(10));
    });

    test('flags torso lean beyond the prototype threshold', () {
      final result = analyzer.analyze(
        _pose(
          leftShoulder: const PoseLandmarkPoint(
            x: 0.48,
            y: 0.25,
            visibility: 0.95,
          ),
          rightShoulder: const PoseLandmarkPoint(
            x: 0.78,
            y: 0.25,
            visibility: 0.95,
          ),
        ),
      );

      expect(result.classification, PostureFrameClassification.needsAdjustment);
      expect(result.torsoLeanDegrees, greaterThan(12));
    });

    test(
      'missing or low-visibility landmarks are invalid, not bad posture',
      () {
        expect(
          analyzer.analyze(null).classification,
          PostureFrameClassification.invalid,
        );
        final result = analyzer.analyze(
          _pose(
            leftHip: const PoseLandmarkPoint(x: 0.4, y: 0.75, visibility: 0.2),
          ),
        );
        expect(result.classification, PostureFrameClassification.invalid);
      },
    );
  });

  group('PostureSessionTracker', () {
    test('smooths noisy classifications before changing the label', () {
      final tracker = PostureSessionTracker();
      tracker.addFrame(_pose(), Duration.zero);
      tracker.addFrame(_pose(), const Duration(milliseconds: 300));
      expect(tracker.status, PostureDisplayStatus.positionYourself);
      tracker.addFrame(_pose(), const Duration(milliseconds: 600));
      expect(tracker.status, PostureDisplayStatus.good);

      tracker.addFrame(_tiltedPose(), const Duration(milliseconds: 900));
      expect(tracker.status, PostureDisplayStatus.good);
      tracker.addFrame(_tiltedPose(), const Duration(milliseconds: 1200));
      tracker.addFrame(_tiltedPose(), const Duration(milliseconds: 1500));
      expect(tracker.status, PostureDisplayStatus.adjust);
    });

    test('uses Position yourself after repeated invalid frames', () {
      final tracker = PostureSessionTracker();
      for (var index = 0; index < 3; index++) {
        tracker.addFrame(_pose(), Duration(milliseconds: index * 300));
      }
      expect(tracker.status, PostureDisplayStatus.good);

      for (var index = 3; index < 6; index++) {
        tracker.addFrame(null, Duration(milliseconds: index * 300));
      }
      expect(tracker.status, PostureDisplayStatus.positionYourself);
    });

    test('computes percentage from valid pose time only', () {
      final tracker = PostureSessionTracker();
      for (var index = 0; index <= 4; index++) {
        tracker.addFrame(_pose(), Duration(milliseconds: index * 500));
      }
      tracker.addFrame(null, const Duration(milliseconds: 2500));
      for (var index = 6; index <= 10; index++) {
        tracker.addFrame(_tiltedPose(), Duration(milliseconds: index * 500));
      }

      final summary = tracker.summary;
      expect(summary.validDuration, const Duration(seconds: 4));
      expect(summary.acceptableDuration, const Duration(seconds: 2));
      expect(summary.acceptablePercentage, 50);
    });

    test('short valid detection remains unavailable', () {
      final tracker = PostureSessionTracker();
      tracker.addFrame(_pose(), Duration.zero);
      tracker.addFrame(_pose(), const Duration(milliseconds: 500));
      tracker.addFrame(_pose(), const Duration(seconds: 1));

      expect(tracker.summary.hasSufficientData, isFalse);
      expect(tracker.summary.acceptablePercentage, isNull);
    });

    test('reset clears durations, smoothing, and previous status', () {
      final tracker = PostureSessionTracker();
      for (var index = 0; index < 8; index++) {
        tracker.addFrame(_pose(), Duration(milliseconds: index * 500));
      }
      expect(tracker.summary.hasSufficientData, isTrue);

      tracker.reset();

      expect(tracker.status, PostureDisplayStatus.positionYourself);
      expect(tracker.summary.validDuration, Duration.zero);
      expect(tracker.summary.acceptableDuration, Duration.zero);
      expect(tracker.summary.acceptablePercentage, isNull);
    });
  });

  test('disabled posture monitoring prevents inference from running', () {
    expect(
      shouldRunPostureAnalysis(
        monitoringEnabled: false,
        rehearsalStarted: true,
        cameraReady: true,
        cameraEnabled: true,
      ),
      isFalse,
    );
    expect(
      shouldRunPostureAnalysis(
        monitoringEnabled: true,
        rehearsalStarted: true,
        cameraReady: true,
        cameraEnabled: true,
      ),
      isTrue,
    );
  });
}

PoseFrameLandmarks _pose({
  PoseLandmarkPoint leftShoulder = const PoseLandmarkPoint(
    x: 0.35,
    y: 0.25,
    visibility: 0.95,
  ),
  PoseLandmarkPoint rightShoulder = const PoseLandmarkPoint(
    x: 0.65,
    y: 0.25,
    visibility: 0.95,
  ),
  PoseLandmarkPoint leftHip = const PoseLandmarkPoint(
    x: 0.4,
    y: 0.75,
    visibility: 0.95,
  ),
  PoseLandmarkPoint rightHip = const PoseLandmarkPoint(
    x: 0.6,
    y: 0.75,
    visibility: 0.95,
  ),
}) {
  return PoseFrameLandmarks(
    leftShoulder: leftShoulder,
    rightShoulder: rightShoulder,
    leftHip: leftHip,
    rightHip: rightHip,
  );
}

PoseFrameLandmarks _tiltedPose() {
  return _pose(
    rightShoulder: const PoseLandmarkPoint(x: 0.65, y: 0.38, visibility: 0.95),
  );
}
