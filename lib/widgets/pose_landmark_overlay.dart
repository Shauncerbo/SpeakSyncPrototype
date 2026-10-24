import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/posture_analysis.dart';

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
    final points = <PoseLandmarkPoint>[
      frame.landmarks.leftShoulder,
      frame.landmarks.rightShoulder,
      frame.landmarks.leftHip,
      frame.landmarks.rightHip,
    ];
    if (points.any((point) => point.visibility < minimumVisibility)) {
      return;
    }

    Offset position(PoseLandmarkPoint point) =>
        PoseOverlayTransform.landmarkToCanvas(
          point: point,
          canvasSize: size,
          imageSize: imageSize,
          mirrorHorizontally: frame.mirrorHorizontally,
        );

    final positions = points.map(position).toList(growable: false);
    final linePaint = Paint()
      ..color = const Color(0xE600E5C4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()
      ..color = const Color(0xFF8CFFE9)
      ..style = PaintingStyle.fill;
    for (final connection in const <(int, int)>[
      (0, 1),
      (0, 2),
      (1, 3),
      (2, 3),
    ]) {
      canvas.drawLine(
        positions[connection.$1],
        positions[connection.$2],
        linePaint,
      );
    }
    for (final point in positions) {
      canvas.drawCircle(point, 5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PoseLandmarkPainter oldDelegate) =>
      oldDelegate.frames != frames ||
      oldDelegate.minimumVisibility != minimumVisibility;
}

class PoseOverlayDebugToggle extends StatelessWidget {
  /// Developer diagnostic component. The student rehearsal UI intentionally
  /// does not mount this control or [PoseLandmarkOverlay].
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
