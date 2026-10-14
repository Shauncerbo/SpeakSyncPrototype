import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/face_attention.dart';
import 'package:speaksync_prototype/services/posture_landmarker_service.dart';

FaceObservation face({double yaw = 0, double pitch = 0}) {
  final y = yaw * math.pi / 180;
  final p = pitch * math.pi / 180;
  final cy = math.cos(y), sy = math.sin(y), cp = math.cos(p), sp = math.sin(p);
  return FaceObservation(
    matrix: [
      cy,
      0,
      -sy,
      0,
      sy * sp,
      cp,
      cy * sp,
      0,
      sy * cp,
      -sp,
      cy * cp,
      0,
      0,
      0,
      -40,
      1,
    ],
    landmarks: const [
      [.5, .45, -.1],
      [.4, .4, 0],
      [.6, .4, 0],
      [.5, .7, 0],
      [.5, .2, 0],
    ],
  );
}

void main() {
  test('Column-major landmark-derived matrix yields correct head angles', () {
    for (final yaw in [-60.0, -25.0, 0.0, 25.0, 60.0]) {
      for (final pitch in [-40.0, 0.0, 40.0]) {
        final result = const HeadOrientationAnalyzer().analyze(
          face(yaw: yaw, pitch: pitch),
        )!;
        expect(result.yawDegrees, closeTo(yaw, .0001));
        expect(result.pitchDegrees, closeTo(pitch, .0001));
      }
    }
  });

  for (final example in [
    (0.0, 0.0, true),
    (25.0, 20.0, true),
    (26.0, 0.0, false),
    (-35.0, 0.0, false),
    (0.0, 21.0, false),
    (0.0, -30.0, false),
  ]) {
    test('Classifies yaw ${example.$1} pitch ${example.$2}', () {
      final tracker = FaceAttentionTracker();
      for (var i = 0; i < 3; i++) {
        tracker.addFrame(
          face(yaw: example.$1, pitch: example.$2),
          Duration(milliseconds: i * 500),
        );
      }
      expect(
        tracker.status,
        example.$3
            ? FaceAttentionState.facingCamera
            : FaceAttentionState.lookingAway,
      );
    });
  }

  test(
    'Missing, malformed, nonfinite or degenerate landmarks are unavailable',
    () {
      final valid = face();
      for (final invalid in <FaceObservation?>[
        null,
        FaceObservation(matrix: const [], landmarks: valid.landmarks),
        FaceObservation(matrix: valid.matrix, landmarks: const []),
        FaceObservation(matrix: List.filled(16, 0), landmarks: valid.landmarks),
        FaceObservation(
          matrix: [...valid.matrix]..[8] = double.nan,
          landmarks: valid.landmarks,
        ),
        FaceObservation(
          matrix: valid.matrix,
          landmarks: List.filled(5, [.5, .5, 0]),
        ),
        FaceObservation(
          matrix: valid.matrix,
          landmarks: [...valid.landmarks]..[0] = [2, .5, 0],
        ),
        FaceObservation(
          matrix: valid.matrix,
          landmarks: [...valid.landmarks]..[0] = [.5, .5, double.infinity],
        ),
      ]) {
        expect(const HeadOrientationAnalyzer().analyze(invalid), isNull);
        final tracker = FaceAttentionTracker();
        expect(
          tracker.addFrame(invalid, Duration.zero),
          FaceAttentionState.unavailable,
        );
        expect(tracker.summary.percentage, isNull);
      }
    },
  );

  test(
    'Malformed native face payload is isolated from pose result parsing',
    () {
      expect(
        parseFaceObservation({'matrix': 'wrong', 'landmarks': []}),
        isNull,
      );
      expect(parseFaceObservation(null), isNull);
      final valid = face();
      expect(
        parseFaceObservation({
          'matrix': valid.matrix,
          'landmarks': valid.landmarks,
        }),
        isNotNull,
      );
    },
  );

  test(
    'Three-sample smoothing and recovery hysteresis avoid label flicker',
    () {
      final tracker = FaceAttentionTracker();
      for (var i = 0; i < 3; i++) {
        tracker.addFrame(face(), Duration(milliseconds: i * 500));
      }
      expect(tracker.status, FaceAttentionState.facingCamera);
      tracker.addFrame(face(yaw: 50), const Duration(milliseconds: 1500));
      expect(tracker.status, FaceAttentionState.facingCamera);
      tracker.addFrame(face(yaw: 50), const Duration(milliseconds: 2000));
      expect(tracker.status, FaceAttentionState.lookingAway);
      for (var i = 5; i < 8; i++) {
        tracker.addFrame(face(yaw: 23), Duration(milliseconds: i * 500));
      }
      expect(tracker.status, FaceAttentionState.lookingAway);
      for (var i = 8; i < 11; i++) {
        tracker.addFrame(face(yaw: 10), Duration(milliseconds: i * 500));
      }
      expect(tracker.status, FaceAttentionState.facingCamera);
    },
  );

  test(
    'Only valid classified time contributes, with a three-second minimum',
    () {
      final tracker = FaceAttentionTracker();
      for (var i = 0; i < 8; i++) {
        tracker.addFrame(face(), Duration(milliseconds: i * 500));
      }
      expect(tracker.summary.validDuration, const Duration(milliseconds: 2500));
      expect(tracker.summary.percentage, isNull);
      tracker.addFrame(face(), const Duration(seconds: 4));
      expect(tracker.summary.validDuration, const Duration(seconds: 3));
      expect(tracker.summary.percentage, 100);
      tracker.addFrame(null, const Duration(milliseconds: 4500));
      expect(tracker.status, FaceAttentionState.unavailable);
      tracker.addFrame(null, const Duration(seconds: 15));
      expect(tracker.summary.validDuration, const Duration(seconds: 3));
      expect(tracker.summary.percentage, 100);
    },
  );

  test('Valid looking-away time can genuinely measure zero percent', () {
    final tracker = FaceAttentionTracker();
    for (var i = 0; i < 9; i++) {
      tracker.addFrame(face(yaw: 50), Duration(milliseconds: i * 500));
    }
    expect(tracker.summary.validDuration, const Duration(seconds: 3));
    expect(tracker.summary.facingDuration, Duration.zero);
    expect(tracker.summary.percentage, 0);
  });

  test('Mixed facing and away time uses valid-duration denominator only', () {
    final tracker = FaceAttentionTracker();
    for (var i = 0; i < 9; i++) {
      tracker.addFrame(face(), Duration(milliseconds: i * 500));
    }
    for (var i = 9; i < 13; i++) {
      tracker.addFrame(face(yaw: 55), Duration(milliseconds: i * 500));
    }
    expect(tracker.summary.validDuration, const Duration(seconds: 5));
    expect(tracker.summary.facingDuration, const Duration(seconds: 4));
    expect(tracker.summary.percentage, 80);
    tracker.addFrame(null, const Duration(seconds: 100));
    expect(tracker.summary.percentage, 80);
  });

  test(
    'Missing intervals, interruptions and stale callbacks do not count away',
    () {
      final tracker = FaceAttentionTracker();
      for (var i = 0; i < 9; i++) {
        tracker.addFrame(face(), Duration(milliseconds: i * 500));
      }
      tracker.expire(const Duration(seconds: 6));
      expect(tracker.status, FaceAttentionState.unavailable);
      tracker.addFrame(face(yaw: 50), const Duration(seconds: 10));
      expect(tracker.summary.validDuration, const Duration(seconds: 3));
      tracker.interrupt();
      expect(tracker.status, FaceAttentionState.unavailable);
      expect(tracker.summary.percentage, 100);
    },
  );

  test('Monitoring disabled consumes no face time or classification', () {
    final tracker = FaceAttentionTracker();
    for (var i = 0; i < 30; i++) {
      tracker.addFrame(face(), Duration(milliseconds: i * 500), enabled: false);
    }
    expect(tracker.status, FaceAttentionState.unavailable);
    expect(tracker.summary.validDuration, Duration.zero);
    expect(tracker.summary.percentage, isNull);
  });

  test('Session restart clears all previous face state and durations', () {
    final tracker = FaceAttentionTracker();
    for (var i = 0; i < 9; i++) {
      tracker.addFrame(face(), Duration(milliseconds: i * 500));
    }
    tracker.reset();
    expect(tracker.status, FaceAttentionState.unavailable);
    expect(tracker.summary.validDuration, Duration.zero);
    expect(tracker.summary.facingDuration, Duration.zero);
    expect(tracker.summary.percentage, isNull);
  });

  test('Looking-away warning requires persistence and sustained recovery', () {
    final warnings = FaceAttentionWarningController();
    for (var i = 0; i < 6; i++) {
      expect(
        warnings.update(
          FaceAttentionState.lookingAway,
          Duration(milliseconds: i * 500),
        ),
        isFalse,
      );
    }
    expect(
      warnings.update(
        FaceAttentionState.lookingAway,
        const Duration(seconds: 3),
      ),
      isTrue,
    );
    for (var i = 7; i < 11; i++) {
      expect(
        warnings.update(
          FaceAttentionState.facingCamera,
          Duration(milliseconds: i * 500),
        ),
        isTrue,
      );
    }
    expect(
      warnings.update(
        FaceAttentionState.facingCamera,
        const Duration(milliseconds: 5500),
      ),
      isFalse,
    );
  });

  test('Missing face, disabled alerts, gaps and restart clear warnings', () {
    final warnings = FaceAttentionWarningController();
    void warn() {
      warnings.reset();
      for (var i = 0; i < 7; i++) {
        warnings.update(
          FaceAttentionState.lookingAway,
          Duration(milliseconds: i * 500),
        );
      }
      expect(warnings.visible, isTrue);
    }

    warn();
    expect(
      warnings.update(
        FaceAttentionState.unavailable,
        const Duration(milliseconds: 3500),
      ),
      isFalse,
    );
    warn();
    expect(
      warnings.update(
        FaceAttentionState.lookingAway,
        const Duration(milliseconds: 3500),
        liveAlertsEnabled: false,
      ),
      isFalse,
    );
    warn();
    expect(
      warnings.update(
        FaceAttentionState.lookingAway,
        const Duration(seconds: 10),
      ),
      isFalse,
    );
    warn();
    warnings.reset();
    expect(warnings.visible, isFalse);
  });
}
