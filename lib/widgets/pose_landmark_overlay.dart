import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/posture_analysis.dart';

const poseSkeletonConnections = <(int, int)>[
  (0, 1),
  (1, 2),
  (2, 3),
  (3, 7),
  (0, 4),
  (4, 5),
  (5, 6),
  (6, 8),
  (9, 10),
  (11, 12),
  (11, 13),
  (13, 15),
  (15, 17),
  (15, 19),
  (15, 21),
  (12, 14),
  (14, 16),
  (16, 18),
  (16, 20),
  (16, 22),
  (11, 23),
  (12, 24),
  (23, 24),
  (23, 25),
  (25, 27),
  (27, 29),
  (29, 31),
  (27, 31),
  (24, 26),
  (26, 28),
  (28, 30),
  (30, 32),
  (28, 32),
];

class PoseOverlayFrame {
  const PoseOverlayFrame({
    required this.landmarks,
    required this.imageWidth,
    required this.imageHeight,
    required this.mirrorHorizontally,
  });

  final PoseFrameLandmarks landmarks;
  final int imageWidth;
  final int imageHeight;
  final bool mirrorHorizontally;
}

class PoseOverlayTransform {
  const PoseOverlayTransform._();

  static Rect containedImageRect({
    required Size canvasSize,
    required Size imageSize,
  }) {
    if (canvasSize.isEmpty || imageSize.isEmpty) return Offset.zero & Size.zero;
    final scale = math.min(
      canvasSize.width / imageSize.width,
      canvasSize.height / imageSize.height,
    );
    final fitted = Size(imageSize.width * scale, imageSize.height * scale);
    return Rect.fromLTWH(
      (canvasSize.width - fitted.width) / 2,
      (canvasSize.height - fitted.height) / 2,
      fitted.width,
      fitted.height,
    );
  }

  static Offset landmarkToCanvas({
    required PoseLandmarkPoint point,
    required Size canvasSize,
    required Size imageSize,
    required bool mirrorHorizontally,
  }) {
    final rect = containedImageRect(
      canvasSize: canvasSize,
      imageSize: imageSize,
    );
    final normalizedX = mirrorHorizontally ? 1 - point.x : point.x;
    return Offset(
      rect.left + normalizedX * rect.width,
      rect.top + point.y * rect.height,
    );
  }
}

class PoseLandmarkOverlay extends StatelessWidget {
  const PoseLandmarkOverlay({
    super.key,
    required this.frames,
    this.minimumVisibility = 0.6,
  });

  final ValueListenable<PoseOverlayFrame?> frames;
  final double minimumVisibility;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: PoseLandmarkPainter(
          frames: frames,
          minimumVisibility: minimumVisibility,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class PoseLandmarkPainter extends CustomPainter {
  PoseLandmarkPainter({required this.frames, required this.minimumVisibility})
    : super(repaint: frames);

  final ValueListenable<PoseOverlayFrame?> frames;
  final double minimumVisibility;

  PoseOverlayFrame? get currentFrame => frames.value;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frames.value;
    if (frame == null || frame.imageWidth <= 0 || frame.imageHeight <= 0) {
      return;
    }
    final imageSize = Size(
      frame.imageWidth.toDouble(),
      frame.imageHeight.toDouble(),
    );
    final hasFullPose = frame.landmarks.allPoints.length >= 33;
    final points = hasFullPose
        ? frame.landmarks.allPoints
        : <PoseLandmarkPoint>[
            frame.landmarks.leftShoulder,
            frame.landmarks.rightShoulder,
            frame.landmarks.leftHip,
            frame.landmarks.rightHip,
          ];

    Offset position(PoseLandmarkPoint point) =>
        PoseOverlayTransform.landmarkToCanvas(
          point: point,
          canvasSize: size,
          imageSize: imageSize,
          mirrorHorizontally: frame.mirrorHorizontally,
        );

    final positions = points.map(position).toList(growable: false);
    final linePaint = Paint()
      ..color = const Color(0xF200E5C4)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final connections = hasFullPose
        ? poseSkeletonConnections
        : const <(int, int)>[(0, 1), (0, 2), (1, 3), (2, 3)];
    for (final connection in connections) {
      if (connection.$1 >= points.length || connection.$2 >= points.length) {
        continue;
      }
      if (points[connection.$1].visibility < minimumVisibility ||
          points[connection.$2].visibility < minimumVisibility) {
        continue;
      }
      canvas.drawLine(
        positions[connection.$1],
        positions[connection.$2],
        linePaint,
      );
    }
    for (var index = 0; index < positions.length; index++) {
      if (points[index].visibility < minimumVisibility) continue;
      canvas.drawCircle(positions[index], hasFullPose ? 3.8 : 5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PoseLandmarkPainter oldDelegate) =>
      oldDelegate.frames != frames ||
      oldDelegate.minimumVisibility != minimumVisibility;
}

class PoseOverlayDebugToggle extends StatelessWidget {
  /// Developer diagnostic component retained separately from the student
  /// full-body setting. Normal upper-body rehearsals do not mount the overlay.
  const PoseOverlayDebugToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      key: const Key('show_pose_landmarks_toggle'),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Show Pose Landmarks',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      subtitle: const Text(
        'Development overlay only',
        style: TextStyle(color: Color(0xFF9EB1C7), fontSize: 12),
      ),
      activeTrackColor: const Color(0xFF00A58E),
    );
  }
}
