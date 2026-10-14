import 'dart:math' as math;

/// Provisional head-orientation thresholds, NOT validated eye-contact rules.
/// Calibrate on physical phones, camera distances, lighting and diverse users.
class FaceAttentionThresholds {
  const FaceAttentionThresholds({
    this.maximumYawDegrees = 25,
    this.maximumPitchDegrees = 20,
    this.recoveryYawDegrees = 20,
    this.recoveryPitchDegrees = 15,
    this.minimumValidDuration = const Duration(seconds: 3),
    this.maximumSampleGap = const Duration(milliseconds: 1200),
    this.smoothingWindowSize = 3,
    this.minimumSamples = 3,
    this.warningDelay = const Duration(seconds: 3),
    this.recoveryDelay = const Duration(seconds: 2),
  });

  final double maximumYawDegrees;
  final double maximumPitchDegrees;
  final double recoveryYawDegrees;
  final double recoveryPitchDegrees;
  final Duration minimumValidDuration;
  final Duration maximumSampleGap;
  final int smoothingWindowSize;
  final int minimumSamples;
  final Duration warningDelay;
  final Duration recoveryDelay;
}

enum FaceAttentionState { facingCamera, lookingAway, unavailable }

String faceAttentionLabel(FaceAttentionState state) => switch (state) {
  FaceAttentionState.facingCamera => 'Facing Camera',
  FaceAttentionState.lookingAway => 'Looking Away',
  FaceAttentionState.unavailable => 'Unavailable',
};

/// The landmark-derived MediaPipe canonical-face transformation, column-major.
/// Only coordinates/matrix are returned; no frame or face identity is retained.
class FaceObservation {
  const FaceObservation({required this.matrix, required this.landmarks});

  factory FaceObservation.fromMap(Map<Object?, Object?> map) => FaceObservation(
    matrix: (map['matrix'] as List).map((v) => (v as num).toDouble()).toList(),
    landmarks: (map['landmarks'] as List)
        .map(
          (point) => (point as List).map((v) => (v as num).toDouble()).toList(),
        )
        .toList(),
  );

  final List<double> matrix;
  // Five real points: nose, both outer eyes, chin and forehead.
  final List<List<double>> landmarks;
}

class HeadOrientation {
  const HeadOrientation(this.yawDegrees, this.pitchDegrees);
  final double yawDegrees;
  final double pitchDegrees;
}

class HeadOrientationAnalyzer {
  const HeadOrientationAnalyzer();

  HeadOrientation? analyze(FaceObservation? face) {
    if (face == null ||
        face.matrix.length != 16 ||
        face.landmarks.length != 5) {
      return null;
    }
    if (face.matrix.any((v) => !v.isFinite) ||
        face.landmarks.any(
          (p) =>
              p.length != 3 ||
              p.any((v) => !v.isFinite) ||
              p[0] < 0 ||
              p[0] > 1 ||
              p[1] < 0 ||
              p[1] > 1,
        )) {
      return null;
    }
    final eyes = face.landmarks;
    if (math.sqrt(
              math.pow(eyes[1][0] - eyes[2][0], 2) +
                  math.pow(eyes[1][1] - eyes[2][1], 2),
            ) <
            .02 ||
        (eyes[3][1] - eyes[4][1]).abs() < .02) {
      return null;
    }
    final m = face.matrix;
    // Reject degenerate/sheared matrices, not just missing landmark lists.
    final axes = [
      for (final start in [0, 4, 8]) m.sublist(start, start + 3),
    ];
    double dot(List<double> a, List<double> b) =>
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    for (final axis in axes) {
      final length = math.sqrt(dot(axis, axis));
      if (length < .5 || length > 1.5) return null;
    }
    for (var i = 0; i < axes.length; i++) {
      for (var j = i + 1; j < axes.length; j++) {
        if (dot(axes[i], axes[j]).abs() > .2) return null;
      }
    }
    if ((m[15] - 1).abs() > .01) return null;
    final yaw = math.atan2(m[8], m[10]) * 180 / math.pi;
    final pitch =
        math.atan2(-m[9], math.sqrt(m[8] * m[8] + m[10] * m[10])) *
        180 /
        math.pi;
    return HeadOrientation(yaw, pitch);
  }
}

class FaceAttentionSummary {
  const FaceAttentionSummary({
    required this.validDuration,
    required this.facingDuration,
    this.minimumValidDuration = const Duration(seconds: 3),
  });
  final Duration validDuration;
  final Duration facingDuration;
  final Duration minimumValidDuration;

  // Persistence contract: sufficient valid face evidence, never session time.
  double? get percentage =>
      validDuration < minimumValidDuration || validDuration <= Duration.zero
      ? null
      : facingDuration.inMicroseconds / validDuration.inMicroseconds * 100;
}

/// Smooths orientation, applies hysteresis, and integrates only adjacent valid
/// samples. Missing/stale data breaks continuity immediately, never counts away.
class FaceAttentionTracker {
  FaceAttentionTracker({this.thresholds = const FaceAttentionThresholds()});
  final FaceAttentionThresholds thresholds;
  final analyzer = const HeadOrientationAnalyzer();
  final List<HeadOrientation> _window = [];
  Duration _valid = Duration.zero;
  Duration _facing = Duration.zero;
  Duration? _last;
  FaceAttentionState _status = FaceAttentionState.unavailable;

  FaceAttentionState get status => _status;
  FaceAttentionSummary get summary => FaceAttentionSummary(
    validDuration: _valid,
    facingDuration: _facing,
    minimumValidDuration: thresholds.minimumValidDuration,
  );

  FaceAttentionState addFrame(
    FaceObservation? face,
    Duration timestamp, {
    bool enabled = true,
  }) {
    if (!enabled) {
      interrupt();
      return _status;
    }
    final orientation = analyzer.analyze(face);
    if (orientation == null) {
      interrupt();
      return _status;
    }
    final previous = _last;
    final previousStatus = _status;
    if (previous != null &&
        (timestamp <= previous ||
            timestamp - previous > thresholds.maximumSampleGap)) {
      interrupt();
    }
    _window.add(orientation);
    if (_window.length > thresholds.smoothingWindowSize) _window.removeAt(0);
    if (_window.length < thresholds.minimumSamples) {
      _last = timestamp;
      return _status;
    }
    final yaw =
        _window.map((v) => v.yawDegrees.abs()).reduce((a, b) => a + b) /
        _window.length;
    final pitch =
        _window.map((v) => v.pitchDegrees.abs()).reduce((a, b) => a + b) /
        _window.length;
    final recovery = _status == FaceAttentionState.lookingAway;
    // Tolerate floating-point roundoff at the exact inclusive boundaries.
    const epsilon = 1e-7;
    _status =
        yaw <=
                (recovery
                        ? thresholds.recoveryYawDegrees
                        : thresholds.maximumYawDegrees) +
                    epsilon &&
            pitch <=
                (recovery
                        ? thresholds.recoveryPitchDegrees
                        : thresholds.maximumPitchDegrees) +
                    epsilon
        ? FaceAttentionState.facingCamera
        : FaceAttentionState.lookingAway;
    if (previous != null && previousStatus != FaceAttentionState.unavailable) {
      final gap = timestamp - previous;
      if (gap > Duration.zero && gap <= thresholds.maximumSampleGap) {
        _valid += gap;
        if (previousStatus == FaceAttentionState.facingCamera) _facing += gap;
      }
    }
    _last = timestamp;
    return _status;
  }

  void expire(Duration timestamp) {
    if (_last != null && timestamp - _last! > thresholds.maximumSampleGap) {
      interrupt();
    }
  }

  void interrupt() {
    _last = null;
    _window.clear();
    _status = FaceAttentionState.unavailable;
  }

  void reset() {
    interrupt();
    _valid = Duration.zero;
    _facing = Duration.zero;
  }
}

class FaceAttentionWarningController {
  FaceAttentionWarningController({
    this.thresholds = const FaceAttentionThresholds(),
  });
  final FaceAttentionThresholds thresholds;
  Duration? _awaySince;
  Duration? _facingSince;
  Duration? _lastTimestamp;
  bool _visible = false;
  bool get visible => _visible;

  bool update(
    FaceAttentionState state,
    Duration timestamp, {
    bool liveAlertsEnabled = true,
  }) {
    if (!liveAlertsEnabled || state == FaceAttentionState.unavailable) {
      reset();
      return false;
    }
    if (_lastTimestamp != null &&
        (timestamp <= _lastTimestamp! ||
            timestamp - _lastTimestamp! > thresholds.maximumSampleGap)) {
      reset();
    }
    _lastTimestamp = timestamp;
    if (state == FaceAttentionState.lookingAway) {
      _facingSince = null;
      _awaySince ??= timestamp;
      if (timestamp - _awaySince! >= thresholds.warningDelay) _visible = true;
    } else {
      _awaySince = null;
      _facingSince ??= timestamp;
      if (timestamp - _facingSince! >= thresholds.recoveryDelay) {
        _visible = false;
      }
    }
    return _visible;
  }

  void reset() {
    _awaySince = null;
    _facingSince = null;
    _lastTimestamp = null;
    _visible = false;
  }
}
