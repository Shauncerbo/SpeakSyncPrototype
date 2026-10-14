import 'dart:math' as math;

import 'posture_analysis.dart';

enum CameraFramingState { unavailable, tooClose, proper, tooFar }

class CameraFramingThresholds {
  const CameraFramingThresholds({
    this.minimumLandmarkVisibility = 0.6,
    this.tooFarThreshold = 0.28,
    this.tooCloseThreshold = 0.52,
    this.hysteresis = 0.03,
    this.shoulderWeight = 0.5,
    this.torsoWeight = 0.5,
  });

  /// Prototype normalized thresholds. They are not scientifically validated
  /// and should be calibrated using real-device tests with target students.
  final double minimumLandmarkVisibility;
  final double tooFarThreshold;
  final double tooCloseThreshold;
  final double hysteresis;
  final double shoulderWeight;
  final double torsoWeight;
}

class CameraFramingMeasurement {
  const CameraFramingMeasurement({
    required this.state,
    this.normalizedBodyScale,
    this.normalizedShoulderWidth,
    this.normalizedTorsoHeight,
  });

  final CameraFramingState state;
  final double? normalizedBodyScale;
  final double? normalizedShoulderWidth;
  final double? normalizedTorsoHeight;
}

class CameraFramingTracker {
  CameraFramingTracker({this.thresholds = const CameraFramingThresholds()});

  final CameraFramingThresholds thresholds;
  CameraFramingState _state = CameraFramingState.unavailable;

  CameraFramingState get state => _state;

  CameraFramingMeasurement update(PoseFrameLandmarks? landmarks) {
    if (!_hasReliableLandmarks(landmarks)) {
      _state = CameraFramingState.unavailable;
      return const CameraFramingMeasurement(
        state: CameraFramingState.unavailable,
      );
    }

    final pose = landmarks!;
    final shoulderWidth = (pose.rightShoulder.x - pose.leftShoulder.x).abs();
    final shoulderMidX = (pose.leftShoulder.x + pose.rightShoulder.x) / 2;
    final shoulderMidY = (pose.leftShoulder.y + pose.rightShoulder.y) / 2;
    final hipMidX = (pose.leftHip.x + pose.rightHip.x) / 2;
    final hipMidY = (pose.leftHip.y + pose.rightHip.y) / 2;
    final torsoHeight = math.sqrt(
      math.pow(shoulderMidX - hipMidX, 2) + math.pow(shoulderMidY - hipMidY, 2),
    );
    final bodyScale =
        shoulderWidth * thresholds.shoulderWeight +
        torsoHeight * thresholds.torsoWeight;
    _state = _nextState(bodyScale);
    return CameraFramingMeasurement(
      state: _state,
      normalizedBodyScale: bodyScale,
      normalizedShoulderWidth: shoulderWidth,
      normalizedTorsoHeight: torsoHeight,
    );
  }

  bool _hasReliableLandmarks(PoseFrameLandmarks? landmarks) {
    return landmarks != null &&
        landmarks.points.every(
          (point) =>
              point.isFinite &&
              point.visibility >= thresholds.minimumLandmarkVisibility,
        );
  }

  CameraFramingState _nextState(double scale) {
    // Hysteresis makes a current state "sticky" until the body clearly moves
    // beyond the boundary instead of flickering around a single threshold.
    if (_state == CameraFramingState.tooFar &&
        scale < thresholds.tooFarThreshold + thresholds.hysteresis) {
      return CameraFramingState.tooFar;
    }
    if (_state == CameraFramingState.tooClose &&
        scale > thresholds.tooCloseThreshold - thresholds.hysteresis) {
      return CameraFramingState.tooClose;
    }
    if (scale < thresholds.tooFarThreshold) {
      return CameraFramingState.tooFar;
    }
    if (scale > thresholds.tooCloseThreshold) {
      return CameraFramingState.tooClose;
    }
    return CameraFramingState.proper;
  }

  void reset() => _state = CameraFramingState.unavailable;
}

String cameraFramingLabel(CameraFramingState state) => switch (state) {
  CameraFramingState.unavailable => 'Unavailable',
  CameraFramingState.tooClose => 'Too Close',
  CameraFramingState.proper => 'Proper',
  CameraFramingState.tooFar => 'Too Far',
};
