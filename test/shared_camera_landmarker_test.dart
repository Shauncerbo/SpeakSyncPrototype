import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/posture_landmarker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('speaksync/test/shared-camera');
  late List<MethodCall> calls;
  Object? facePayload;
  var poseAvailable = true;

  CameraImage image() {
    // The deprecated map factory avoids another dependency just for a fixture.
    // ignore: deprecated_member_use
    return CameraImage.fromPlatformData({
      'width': 2,
      'height': 2,
      'format': 35,
      'planes': [
        for (var i = 0; i < 3; i++)
          {
            'bytes': Uint8List(4),
            'bytesPerRow': 2,
            'bytesPerPixel': 1,
            'width': 2,
            'height': 2,
          },
      ],
    });
  }

  setUp(() {
    calls = [];
    poseAvailable = true;
    facePayload = {
      'matrix': [
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
      ],
      'landmarks': [
        [.5, .45, -.1],
        [.4, .4, 0.0],
        [.6, .4, 0.0],
        [.5, .7, 0.0],
        [.5, .2, 0.0],
      ],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final point = {'x': .5, 'y': .4, 'visibility': .9};
          return {
            'available': poseAvailable,
            'face': facePayload,
            'leftShoulder': point,
            'rightShoulder': point,
            'leftHip': point,
            'rightHip': point,
            'processingTimeMilliseconds': 80,
            'inferenceWidth': 384,
            'inferenceHeight': 216,
          };
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<PoseLandmarkerFrameResult> analyze(
    MethodChannelPostureLandmarker landmarker,
  ) => landmarker.analyze(
    image: image(),
    rotationDegrees: 90,
    mirrorHorizontally: true,
    timestampMilliseconds: 1000,
    maximumInferenceDimension: 384,
  );

  test(
    'One frame request shares sensor data and returns both pose and face',
    () async {
      final landmarker = MethodChannelPostureLandmarker(channel: channel);
      await landmarker.configureMonitoring(pose: true, face: true);
      calls.clear();
      final result = await analyze(landmarker);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'analyzeFrame');
      expect(calls.single.arguments['analyzePose'], isTrue);
      expect(calls.single.arguments['analyzeFace'], isTrue);
      expect(result.landmarks, isNotNull);
      expect(result.face, isNotNull);
      expect(result.processingDuration.inMilliseconds, 80);
    },
  );

  test('Face-only request works with body monitoring disabled', () async {
    poseAvailable = false;
    final landmarker = MethodChannelPostureLandmarker(channel: channel);
    await landmarker.configureMonitoring(pose: false, face: true);
    calls.clear();
    final result = await analyze(landmarker);
    expect(calls.single.arguments['analyzePose'], isFalse);
    expect(calls.single.arguments['analyzeFace'], isTrue);
    expect(result.landmarks, isNull);
    expect(result.face, isNotNull);
  });

  test('Disabled face flag ignores even a valid face payload', () async {
    final landmarker = MethodChannelPostureLandmarker(channel: channel);
    await landmarker.configureMonitoring(pose: true, face: false);
    calls.clear();
    final result = await analyze(landmarker);
    expect(calls.single.arguments['analyzeFace'], isFalse);
    expect(result.face, isNull);
    expect(result.landmarks, isNotNull);
  });

  test(
    'Malformed face data cannot discard an independently valid pose',
    () async {
      facePayload = {'matrix': 'invalid'};
      final landmarker = MethodChannelPostureLandmarker(channel: channel);
      await landmarker.configureMonitoring(pose: true, face: true);
      final result = await analyze(landmarker);
      expect(result.face, isNull);
      expect(result.landmarks, isNotNull);
    },
  );
}
