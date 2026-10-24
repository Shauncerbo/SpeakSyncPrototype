import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/posture_analysis.dart';
import 'package:speaksync_prototype/services/posture_landmarker_service.dart';
import 'package:speaksync_prototype/widgets/pose_landmark_overlay.dart';

void main() {
  const landmarks = PoseFrameLandmarks(
    leftShoulder: PoseLandmarkPoint(x: 0.2, y: 0.25, visibility: 0.9),
    rightShoulder: PoseLandmarkPoint(x: 0.8, y: 0.25, visibility: 0.9),
    leftHip: PoseLandmarkPoint(x: 0.3, y: 0.75, visibility: 0.9),
    rightHip: PoseLandmarkPoint(x: 0.7, y: 0.75, visibility: 0.9),
  );

  test('portrait normalized coordinates map into portrait preview', () {
    final result = PoseOverlayTransform.landmarkToCanvas(
      point: landmarks.leftShoulder,
      canvasSize: const Size(200, 400),
      imageSize: const Size(100, 200),
      mirrorHorizontally: false,
    );

    expect(result, const Offset(40, 100));
  });

  test('landscape normalized coordinates map into landscape preview', () {
    final result = PoseOverlayTransform.landmarkToCanvas(
      point: landmarks.rightHip,
      canvasSize: const Size(400, 200),
      imageSize: const Size(200, 100),
      mirrorHorizontally: false,
    );

    expect(result, const Offset(280, 150));
  });

  test('contain mapping respects camera-preview letterboxing', () {
    final result = PoseOverlayTransform.landmarkToCanvas(
      point: const PoseLandmarkPoint(x: 0.5, y: 0, visibility: 1),
      canvasSize: const Size(200, 200),
      imageSize: const Size(200, 100),
      mirrorHorizontally: false,
    );

    expect(result, const Offset(100, 50));
  });

  test('front camera coordinates mirror horizontally exactly once', () {
    final result = PoseOverlayTransform.landmarkToCanvas(
      point: landmarks.leftShoulder,
      canvasSize: const Size(200, 400),
      imageSize: const Size(100, 200),
      mirrorHorizontally: true,
    );

    expect(result, const Offset(160, 100));
  });

  test('painter always reads the latest landmark frame', () {
    final first = PoseOverlayFrame(
      landmarks: landmarks,
      imageWidth: 100,
      imageHeight: 200,
      mirrorHorizontally: false,
    );
    final second = PoseOverlayFrame(
      landmarks: landmarks,
      imageWidth: 200,
      imageHeight: 100,
      mirrorHorizontally: true,
    );
    final frames = ValueNotifier<PoseOverlayFrame?>(first);
    final painter = PoseLandmarkPainter(frames: frames, minimumVisibility: 0.6);

    expect(painter.currentFrame, same(first));
    frames.value = second;
    expect(painter.currentFrame, same(second));
    frames.dispose();
  });

  testWidgets('debug overlay toggle is OFF initially and can be enabled', (
    tester,
  ) async {
    var enabled = false;
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoseOverlayDebugToggle(
            value: enabled,
            onChanged: (value) => enabled = value,
          ),
        ),
      ),
    );

    await pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('show_pose_landmarks_toggle')));
    await tester.pump();
    expect(enabled, isTrue);
    await pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  test('posture calculation remains operational without a mounted overlay', () {
    final tracker = PostureSessionTracker();
    for (var index = 0; index < 8; index++) {
      tracker.addFrame(landmarks, Duration(milliseconds: index * 500));
    }

    expect(tracker.summary.acceptablePercentage, 100);
    expect(tracker.status, PostureDisplayStatus.good);
  });

  test('camera rotation handles portrait and landscape for front camera', () {
    const camera = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 90,
    );

    expect(
      cameraImageRotationDegrees(camera, DeviceOrientation.portraitUp),
      90,
    );
    expect(
      cameraImageRotationDegrees(camera, DeviceOrientation.landscapeLeft),
      180,
    );
    expect(
      cameraImageRotationDegrees(camera, DeviceOrientation.landscapeRight),
      0,
    );
  });
}
