import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'posture_analysis.dart';
import 'posture_performance.dart';
import 'face_attention.dart';

class PoseLandmarkerFrameResult {
  const PoseLandmarkerFrameResult({
    required this.landmarks,
    required this.processingDuration,
    required this.conversionDuration,
    required this.inferenceDuration,
    required this.inferenceWidth,
    required this.inferenceHeight,
    this.face,
  });

  final PoseFrameLandmarks? landmarks;
  final Duration processingDuration;
  final Duration conversionDuration;
  final Duration inferenceDuration;
  final int inferenceWidth;
  final int inferenceHeight;
  final FaceObservation? face;
}

/// Optional shared-camera capability; existing pose-only test implementations
/// need not acquire a second camera or change their analyze signature.
abstract interface class CameraLandmarkerMonitoring {
  Future<void> configureMonitoring({required bool pose, required bool face});
}

abstract interface class PostureLandmarker {
  Future<void> initialize();

  Future<PoseLandmarkerFrameResult> analyze({
    required CameraImage image,
    required int rotationDegrees,
    required bool mirrorHorizontally,
    required int timestampMilliseconds,
    required int maximumInferenceDimension,
  });

  Future<void> close();
}

bool shouldRunPostureAnalysis({
  required bool monitoringEnabled,
  required bool rehearsalStarted,
  required bool cameraReady,
  required bool cameraEnabled,
}) => monitoringEnabled && rehearsalStarted && cameraReady && cameraEnabled;

class MethodChannelPostureLandmarker
    implements PostureLandmarker, CameraLandmarkerMonitoring {
  MethodChannelPostureLandmarker({
    MethodChannel channel = const MethodChannel(
      'com.speaksync.speaksync_prototype/posture_landmarker',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;
  bool _poseEnabled = true;
  bool _faceEnabled = false;

  @override
  Future<void> configureMonitoring({
    required bool pose,
    required bool face,
  }) async {
    _poseEnabled = pose;
    _faceEnabled = face;
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('configureMonitoring', {
      'pose': pose,
      'face': face,
    });
  }

  @override
  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      throw const PostureLandmarkerException(
        'On-device posture analysis is currently available on Android.',
      );
    }
    await _channel.invokeMethod<void>('initialize', {
      'poseEnabled': _poseEnabled,
    });
  }

  @override
  Future<PoseLandmarkerFrameResult> analyze({
    required CameraImage image,
    required int rotationDegrees,
    required bool mirrorHorizontally,
    required int timestampMilliseconds,
    required int maximumInferenceDimension,
  }) async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'analyzeFrame',
      <String, Object?>{
        'width': image.width,
        'analyzePose': _poseEnabled,
        'analyzeFace': _faceEnabled,
        'height': image.height,
        'format': image.format.group.name,
        'rotationDegrees': rotationDegrees,
        'mirrorHorizontally': mirrorHorizontally,
        'timestampMilliseconds': timestampMilliseconds,
        'maximumInferenceDimension': boundedInferenceDimension(
          maximumInferenceDimension,
        ),
        'planes': image.planes
            .map(
              (plane) => <String, Object?>{
                // StandardMessageCodec must copy the platform message once,
                // but avoid an additional full-plane copy in Dart first.
                'bytes': plane.bytes,
                'bytesPerRow': plane.bytesPerRow,
                'bytesPerPixel': plane.bytesPerPixel ?? 1,
              },
            )
            .toList(growable: false),
      },
    );
    final processingMilliseconds =
        (response?['processingTimeMilliseconds'] as num?)?.round() ?? 0;
    final landmarks = response?['available'] == true
        ? PoseFrameLandmarks.fromMap(response!)
        : null;
    return PoseLandmarkerFrameResult(
      landmarks: landmarks,
      processingDuration: Duration(milliseconds: processingMilliseconds),
      conversionDuration: Duration(
        milliseconds:
            (response?['conversionTimeMilliseconds'] as num?)?.round() ?? 0,
      ),
      inferenceDuration: Duration(
        milliseconds:
            (response?['inferenceTimeMilliseconds'] as num?)?.round() ?? 0,
      ),
      inferenceWidth: (response?['inferenceWidth'] as num?)?.round() ?? 0,
      inferenceHeight: (response?['inferenceHeight'] as num?)?.round() ?? 0,
      face: _faceEnabled ? parseFaceObservation(response?['face']) : null,
    );
  }

  @override
  Future<void> close() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('close');
  }
}

FaceObservation? parseFaceObservation(Object? response) {
  if (response is! Map) return null;
  try {
    return FaceObservation.fromMap(Map<Object?, Object?>.from(response));
  } catch (_) {
    // Malformed native face data must not discard an otherwise valid pose.
    return null;
  }
}

class PostureLandmarkerException implements Exception {
  const PostureLandmarkerException(this.message);

  final String message;

  @override
  String toString() => message;
}

int cameraImageRotationDegrees(
  CameraDescription camera,
  DeviceOrientation orientation,
) {
  const deviceDegrees = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  final degrees = deviceDegrees[orientation] ?? 0;
  if (camera.lensDirection == CameraLensDirection.front) {
    return (camera.sensorOrientation + degrees) % 360;
  }
  return (camera.sensorOrientation - degrees + 360) % 360;
}
