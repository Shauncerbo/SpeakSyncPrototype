import 'dart:math' as math;

/// Prototype posture thresholds. These values are not scientifically
/// validated and must be calibrated with real-device/user testing.
class PostureThresholds {
  const PostureThresholds({
    this.minimumLandmarkVisibility = 0.6,
    this.maximumShoulderTiltDegrees = 10,
    this.maximumTorsoLeanDegrees = 12,
    this.minimumValidDuration = const Duration(seconds: 3),
    this.maximumSampleGap = const Duration(milliseconds: 700),
    this.smoothingWindowSize = 5,
    this.minimumSamplesForStatus = 3,
  });

  final double minimumLandmarkVisibility;
  final double maximumShoulderTiltDegrees;
  final double maximumTorsoLeanDegrees;
  final Duration minimumValidDuration;
  final Duration maximumSampleGap;
  final int smoothingWindowSize;
  final int minimumSamplesForStatus;
}

class PoseLandmarkPoint {
  const PoseLandmarkPoint({
    required this.x,
    required this.y,
    required this.visibility,
  });

  factory PoseLandmarkPoint.fromMap(Map<Object?, Object?> value) {
    return PoseLandmarkPoint(
      x: (value['x'] as num).toDouble(),
      y: (value['y'] as num).toDouble(),
      visibility: (value['visibility'] as num?)?.toDouble() ?? 0,
    );
  }

  final double x;
  final double y;
  final double visibility;

  bool get isFinite => x.isFinite && y.isFinite && visibility.isFinite;
}

class PoseFrameLandmarks {
  const PoseFrameLandmarks({
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftHip,
    required this.rightHip,
  });

  factory PoseFrameLandmarks.fromMap(Map<Object?, Object?> value) {
    PoseLandmarkPoint point(String key) => PoseLandmarkPoint.fromMap(
      Map<Object?, Object?>.from(value[key]! as Map),
    );

    return PoseFrameLandmarks(
      leftShoulder: point('leftShoulder'),
      rightShoulder: point('rightShoulder'),
      leftHip: point('leftHip'),
      rightHip: point('rightHip'),
    );
  }

  final PoseLandmarkPoint leftShoulder;
  final PoseLandmarkPoint rightShoulder;
  final PoseLandmarkPoint leftHip;
  final PoseLandmarkPoint rightHip;

  Iterable<PoseLandmarkPoint> get points => <PoseLandmarkPoint>[
    leftShoulder,
    rightShoulder,
    leftHip,
    rightHip,
  ];
}

enum PostureFrameClassification { acceptable, needsAdjustment, invalid }

enum PostureDisplayStatus { good, adjust, positionYourself }

class PostureFrameResult {
  const PostureFrameResult({
    required this.classification,
    this.shoulderTiltDegrees,
    this.torsoLeanDegrees,
  });

  final PostureFrameClassification classification;
  final double? shoulderTiltDegrees;
  final double? torsoLeanDegrees;
}

class PostureSummary {
  const PostureSummary({
    required this.acceptableDuration,
    required this.validDuration,
    required this.minimumValidDuration,
  });

  final Duration acceptableDuration;
  final Duration validDuration;
  final Duration minimumValidDuration;

  bool get hasSufficientData => validDuration >= minimumValidDuration;

  double? get acceptablePercentage => hasSufficientData
      ? (acceptableDuration.inMilliseconds / validDuration.inMilliseconds * 100)
            .clamp(0, 100)
            .toDouble()
      : null;
}

class PostureAnalyzer {
  const PostureAnalyzer({this.thresholds = const PostureThresholds()});

  final PostureThresholds thresholds;

  PostureFrameResult analyze(PoseFrameLandmarks? landmarks) {
    if (landmarks == null ||
        landmarks.points.any(
          (point) =>
              !point.isFinite ||
              point.visibility < thresholds.minimumLandmarkVisibility,
        )) {
      return const PostureFrameResult(
        classification: PostureFrameClassification.invalid,
      );
    }

    final shouldersDx = landmarks.rightShoulder.x - landmarks.leftShoulder.x;
    final shouldersDy = landmarks.rightShoulder.y - landmarks.leftShoulder.y;
    if (shouldersDx.abs() < 0.000001 && shouldersDy.abs() < 0.000001) {
      return const PostureFrameResult(
        classification: PostureFrameClassification.invalid,
      );
    }

    final shoulderMidX =
        (landmarks.leftShoulder.x + landmarks.rightShoulder.x) / 2;
    final shoulderMidY =
        (landmarks.leftShoulder.y + landmarks.rightShoulder.y) / 2;
    final hipMidX = (landmarks.leftHip.x + landmarks.rightHip.x) / 2;
    final hipMidY = (landmarks.leftHip.y + landmarks.rightHip.y) / 2;
    final torsoDx = shoulderMidX - hipMidX;
    final torsoDy = shoulderMidY - hipMidY;
    if (torsoDx.abs() < 0.000001 && torsoDy.abs() < 0.000001) {
      return const PostureFrameResult(
        classification: PostureFrameClassification.invalid,
      );
    }

    final shoulderTilt = _degrees(
      math.atan2(shouldersDy.abs(), shouldersDx.abs()),
    );
    final torsoLean = _degrees(math.atan2(torsoDx.abs(), torsoDy.abs()));
    final acceptable =
        shoulderTilt <= thresholds.maximumShoulderTiltDegrees &&
        torsoLean <= thresholds.maximumTorsoLeanDegrees;
    return PostureFrameResult(
      classification: acceptable
          ? PostureFrameClassification.acceptable
          : PostureFrameClassification.needsAdjustment,
      shoulderTiltDegrees: shoulderTilt,
      torsoLeanDegrees: torsoLean,
    );
  }

  double _degrees(double radians) => radians * 180 / math.pi;
}

/// Smooths frame classifications and measures only time backed by valid pose
/// landmarks. Gaps and invalid frames are deliberately excluded.
class PostureSessionTracker {
  PostureSessionTracker({
    this.thresholds = const PostureThresholds(),
    PostureAnalyzer? analyzer,
  }) : analyzer = analyzer ?? PostureAnalyzer(thresholds: thresholds);

  final PostureThresholds thresholds;
  final PostureAnalyzer analyzer;
  final List<PostureFrameClassification> _window = [];
  Duration _validDuration = Duration.zero;
  Duration _acceptableDuration = Duration.zero;
  Duration? _lastValidTimestamp;
  PostureFrameClassification? _lastValidClassification;
  int _invalidStreak = 0;
  PostureDisplayStatus _status = PostureDisplayStatus.positionYourself;

  PostureDisplayStatus get status => _status;

  PostureDisplayStatus addFrame(
    PoseFrameLandmarks? landmarks,
    Duration timestamp,
  ) {
    final result = analyzer.analyze(landmarks);
    if (result.classification == PostureFrameClassification.invalid) {
      _invalidStreak++;
      _lastValidTimestamp = null;
      _lastValidClassification = null;
      if (_invalidStreak >= thresholds.minimumSamplesForStatus) {
        _status = PostureDisplayStatus.positionYourself;
      }
      return _status;
    }

    _invalidStreak = 0;
    final previousTimestamp = _lastValidTimestamp;
    final previousClassification = _lastValidClassification;
    if (previousTimestamp != null && previousClassification != null) {
      final gap = timestamp - previousTimestamp;
      if (!gap.isNegative && gap <= thresholds.maximumSampleGap) {
        _validDuration += gap;
        if (previousClassification == PostureFrameClassification.acceptable) {
          _acceptableDuration += gap;
        }
      }
    }
    _lastValidTimestamp = timestamp;
    _lastValidClassification = result.classification;

    _window.add(result.classification);
    if (_window.length > thresholds.smoothingWindowSize) {
      _window.removeAt(0);
    }
    if (_window.length >= thresholds.minimumSamplesForStatus) {
      final acceptable = _window
          .where((value) => value == PostureFrameClassification.acceptable)
          .length;
      final needsAdjustment = _window.length - acceptable;
      _status = acceptable >= needsAdjustment
          ? PostureDisplayStatus.good
          : PostureDisplayStatus.adjust;
    }
    return _status;
  }

  PostureSummary get summary => PostureSummary(
    acceptableDuration: _acceptableDuration,
    validDuration: _validDuration,
    minimumValidDuration: thresholds.minimumValidDuration,
  );

  void reset() {
    _window.clear();
    _validDuration = Duration.zero;
    _acceptableDuration = Duration.zero;
    _lastValidTimestamp = null;
    _lastValidClassification = null;
    _invalidStreak = 0;
    _status = PostureDisplayStatus.positionYourself;
  }
}
