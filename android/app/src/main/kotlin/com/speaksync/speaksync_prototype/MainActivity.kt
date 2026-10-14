package com.speaksync.speaksync_prototype

import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val channelName = "com.speaksync.speaksync_prototype/posture_landmarker"
    private val inferenceExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val frameInFlight = AtomicBoolean(false)
    private var poseLandmarker: PoseLandmarker? = null
    private var faceLandmarker: FaceLandmarker? = null
    @Volatile private var pendingFace: Map<String, Any>? = null
    @Volatile private var pendingTimestamp: Long = -1
    @Volatile private var pendingImage: com.google.mediapipe.framework.image.MPImage? = null
    @Volatile
    private var pendingResult: MethodChannel.Result? = null
    @Volatile
    private var pendingFrameStartedNanos: Long = 0
    @Volatile
    private var pendingInferenceStartedNanos: Long = 0
    @Volatile
    private var pendingInferenceWidth: Int = 0
    @Volatile
    private var pendingInferenceHeight: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initializeLandmarker(result, call.argument<Boolean>("poseEnabled") ?: true)
            "configureMonitoring" -> configureMonitoring(call, result)
            "analyzeFrame" -> analyzeFrame(call, result)
            "close" -> closeLandmarker(result)
            else -> result.notImplemented()
        }
    }

    private fun configureMonitoring(call: MethodCall, result: MethodChannel.Result) {
        inferenceExecutor.execute {
            try {
                if (call.argument<Boolean>("face") == true && faceLandmarker == null) {
                    faceLandmarker = FaceLandmarker.createFromOptions(
                        this,
                        FaceLandmarker.FaceLandmarkerOptions.builder()
                            .setBaseOptions(BaseOptions.builder()
                                .setModelAssetPath("face_landmarker.task").build())
                            .setRunningMode(RunningMode.VIDEO)
                            .setNumFaces(1)
                            .setMinFaceDetectionConfidence(0.6f)
                            .setMinFacePresenceConfidence(0.6f)
                            .setMinTrackingConfidence(0.6f)
                            .setOutputFacialTransformationMatrixes(true)
                            .setOutputFaceBlendshapes(false)
                            .build(),
                    )
                } else if (call.argument<Boolean>("face") != true) {
                    faceLandmarker?.close()
                    faceLandmarker = null
                }
                mainHandler.post { result.success(null) }
            } catch (error: Exception) {
                // Independent task failure: pose/audio continue, face is unavailable.
                Log.w("SpeakSyncFace", "Face Landmarker initialization unavailable", error)
                faceLandmarker = null
                mainHandler.post { result.success(null) }
            }
        }
    }

    private fun initializeLandmarker(result: MethodChannel.Result, poseEnabled: Boolean) {
        inferenceExecutor.execute {
            try {
                if (poseEnabled && poseLandmarker == null) {
                    val baseOptions = BaseOptions.builder()
                        .setModelAssetPath("pose_landmarker_lite.task")
                        .build()
                    val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                        .setBaseOptions(baseOptions)
                        .setRunningMode(RunningMode.LIVE_STREAM)
                        .setNumPoses(1)
                        .setMinPoseDetectionConfidence(0.5f)
                        .setMinPosePresenceConfidence(0.5f)
                        .setMinTrackingConfidence(0.5f)
                        .setResultListener(::onPoseResult)
                        .setErrorListener(::onPoseError)
                        .build()
                    poseLandmarker = PoseLandmarker.createFromOptions(this, options)
                }
                mainHandler.post { result.success(null) }
            } catch (error: Exception) {
                mainHandler.post {
                    if (faceLandmarker != null) result.success(null)
                    else result.error("POSTURE_INIT", error.message, null)
                }
            }
        }
    }

    private fun analyzeFrame(call: MethodCall, result: MethodChannel.Result) {
        val landmarker = poseLandmarker
        if (landmarker == null && faceLandmarker == null) {
            result.error("POSTURE_NOT_READY", "Pose Landmarker is not initialized.", null)
            return
        }
        if (!frameInFlight.compareAndSet(false, true)) {
            result.success(mapOf("available" to false))
            return
        }
        pendingResult = result
        pendingFace = null
        val timestamp = call.argument<Number>("timestampMilliseconds")!!.toLong()
        pendingTimestamp = timestamp
        mainHandler.postDelayed({
            try {
                if (!inferenceExecutor.isShutdown) inferenceExecutor.execute {
                    completeFrame(mapOf("available" to false), timestamp)
                }
            } catch (_: RejectedExecutionException) {
                // Activity shutdown raced the scheduled timeout.
            }
        }, 2000)
        pendingFrameStartedNanos = SystemClock.elapsedRealtimeNanos()
        inferenceExecutor.execute {
            try {
                val bitmap = cameraFrameToBitmap(call.arguments as Map<*, *>)
                pendingInferenceWidth = bitmap.width
                pendingInferenceHeight = bitmap.height
                pendingInferenceStartedNanos = SystemClock.elapsedRealtimeNanos()
                val input = BitmapImageBuilder(bitmap).build()
                pendingImage = input
                if (call.argument<Boolean>("analyzeFace") == true) {
                    try {
                        val faceResult = faceLandmarker?.detectForVideo(input, timestamp)
                        val points = faceResult?.faceLandmarks()?.singleOrNull()
                        val matrix = faceResult?.facialTransformationMatrixes()
                            ?.orElse(null)?.singleOrNull()
                        if (points != null && points.size >= 468 && matrix != null) {
                            val indexes = listOf(1, 33, 263, 152, 10)
                            pendingFace = mapOf(
                                "matrix" to matrix.toList(),
                                "landmarks" to indexes.map { index ->
                                    val p = points[index]
                                    listOf(p.x(), p.y(), p.z())
                                },
                            )
                        }
                    } catch (_: Exception) {
                        pendingFace = null
                    }
                }
                if (pendingTimestamp != timestamp || pendingResult == null) return@execute
                if (call.argument<Boolean>("analyzePose") != false && landmarker != null) {
                    landmarker.detectAsync(input, timestamp)
                } else {
                    completeFrame(mapOf("available" to false))
                }
            } catch (error: Exception) {
                completeFrameError("POSTURE_FRAME", error.message)
            }
        }
    }

    private fun onPoseResult(result: PoseLandmarkerResult, inputImage: com.google.mediapipe.framework.image.MPImage) {
        if (result.timestampMs() != pendingTimestamp) return
        val pose = result.landmarks().firstOrNull()
        if (pose == null || pose.size <= 24) {
            completeFrame(mapOf("available" to false), result.timestampMs())
            return
        }

        fun landmark(index: Int): Map<String, Any> {
            val point = pose[index]
            return mapOf(
                "x" to point.x(),
                "y" to point.y(),
                "visibility" to point.visibility().orElse(0f),
            )
        }

        completeFrame(
            mapOf(
                "available" to true,
                "leftShoulder" to landmark(11),
                "rightShoulder" to landmark(12),
                "leftHip" to landmark(23),
                "rightHip" to landmark(24),
            ), result.timestampMs(),
        )
    }

    private fun onPoseError(error: RuntimeException) {
        // A failed pose does not discard independently measured face results.
        completeFrame(mapOf("available" to false))
    }

    @Synchronized private fun completeFrame(value: Map<String, Any>, expectedTimestamp: Long? = null) {
        if (expectedTimestamp != null && expectedTimestamp != pendingTimestamp) return
        val result = pendingResult ?: return
        pendingResult = null
        val completedNanos = SystemClock.elapsedRealtimeNanos()
        val processingMilliseconds =
            (completedNanos - pendingFrameStartedNanos) / 1_000_000
        val conversionMilliseconds =
            (pendingInferenceStartedNanos - pendingFrameStartedNanos) / 1_000_000
        val inferenceMilliseconds =
            (completedNanos - pendingInferenceStartedNanos) / 1_000_000
        val response = value.toMutableMap().apply {
            pendingFace?.let { put("face", it) }
            put("processingTimeMilliseconds", processingMilliseconds)
            put("conversionTimeMilliseconds", conversionMilliseconds)
            put("inferenceTimeMilliseconds", inferenceMilliseconds)
            put("inferenceWidth", pendingInferenceWidth)
            put("inferenceHeight", pendingInferenceHeight)
        }
        pendingFace = null
        pendingImage?.close()
        pendingImage = null
        frameInFlight.set(false)
        if (result != null) mainHandler.post { result.success(response) }
    }

    @Synchronized private fun completeFrameError(code: String, message: String?) {
        val result = pendingResult ?: return
        pendingResult = null
        pendingFace = null
        pendingImage?.close()
        pendingImage = null
        frameInFlight.set(false)
        if (result != null) mainHandler.post { result.error(code, message, null) }
    }

    private fun closeLandmarker(result: MethodChannel.Result) {
        inferenceExecutor.execute {
            poseLandmarker?.close()
            poseLandmarker = null
            faceLandmarker?.close()
            faceLandmarker = null
            val abandonedFrame = pendingResult
            pendingResult = null
            pendingImage?.close()
            pendingImage = null
            pendingFace = null
            frameInFlight.set(false)
            mainHandler.post {
                abandonedFrame?.success(mapOf("available" to false))
                result.success(null)
            }
        }
    }

    private fun cameraFrameToBitmap(arguments: Map<*, *>): Bitmap {
        val width = (arguments["width"] as Number).toInt()
        val height = (arguments["height"] as Number).toInt()
        val rotation = (arguments["rotationDegrees"] as Number).toFloat()
        val planes = arguments["planes"] as List<*>
        require(planes.size >= 3) { "Expected a YUV420 camera frame." }

        fun plane(index: Int) = planes[index] as Map<*, *>
        val yPlane = plane(0)
        val uPlane = plane(1)
        val vPlane = plane(2)
        val yBytes = yPlane["bytes"] as ByteArray
        val uBytes = uPlane["bytes"] as ByteArray
        val vBytes = vPlane["bytes"] as ByteArray
        val yRowStride = (yPlane["bytesPerRow"] as Number).toInt()
        val uRowStride = (uPlane["bytesPerRow"] as Number).toInt()
        val vRowStride = (vPlane["bytesPerRow"] as Number).toInt()
        val yPixelStride = (yPlane["bytesPerPixel"] as Number).toInt()
        val uPixelStride = (uPlane["bytesPerPixel"] as Number).toInt()
        val vPixelStride = (vPlane["bytesPerPixel"] as Number).toInt()

        // Pose Landmarker uses a small input tensor. Downsampling during YUV
        // conversion avoids allocating a full-resolution RGB bitmap each frame.
        val maxDimension =
            (arguments["maximumInferenceDimension"] as Number).toDouble().coerceIn(128.0, 640.0)
        val scale = minOf(1.0, maxDimension / maxOf(width, height))
        val outputWidth = maxOf(1, (width * scale).toInt())
        val outputHeight = maxOf(1, (height * scale).toInt())
        val pixels = IntArray(outputWidth * outputHeight)

        for (outputY in 0 until outputHeight) {
            val sourceY = outputY * height / outputHeight
            for (outputX in 0 until outputWidth) {
                val sourceX = outputX * width / outputWidth
                val y = yBytes[sourceY * yRowStride + sourceX * yPixelStride].toInt() and 0xff
                val chromaX = sourceX / 2
                val chromaY = sourceY / 2
                val u = uBytes[chromaY * uRowStride + chromaX * uPixelStride].toInt() and 0xff
                val v = vBytes[chromaY * vRowStride + chromaX * vPixelStride].toInt() and 0xff
                pixels[outputY * outputWidth + outputX] = yuvToArgb(y, u, v)
            }
        }

        val bitmap = Bitmap.createBitmap(
            pixels,
            outputWidth,
            outputHeight,
            Bitmap.Config.ARGB_8888,
        )
        val rotated = if (rotation == 0f) {
            bitmap
        } else {
            Bitmap.createBitmap(
                bitmap,
                0,
                0,
                bitmap.width,
                bitmap.height,
                Matrix().apply { postRotate(rotation) },
                true,
            )
        }
        if (rotated !== bitmap) bitmap.recycle()
        // Keep inference coordinates in the rotated sensor space. Flutter
        // mirrors only the debug overlay to match the front-camera preview;
        // posture geometry uses absolute angles and is mirror-invariant.
        return rotated
    }

    private fun yuvToArgb(yValue: Int, uValue: Int, vValue: Int): Int {
        val y = maxOf(0, yValue - 16)
        val u = uValue - 128
        val v = vValue - 128
        val r = ((298 * y + 409 * v + 128) shr 8).coerceIn(0, 255)
        val g = ((298 * y - 100 * u - 208 * v + 128) shr 8).coerceIn(0, 255)
        val b = ((298 * y + 516 * u + 128) shr 8).coerceIn(0, 255)
        return (0xff shl 24) or (r shl 16) or (g shl 8) or b
    }

    override fun onDestroy() {
        // Serialize model teardown with frame conversion/synchronous face work.
        // Do not close image/model resources under an active worker inference.
        mainHandler.removeCallbacksAndMessages(null)
        inferenceExecutor.execute {
            poseLandmarker?.close()
            poseLandmarker = null
            faceLandmarker?.close()
            faceLandmarker = null
            pendingImage?.close()
            pendingImage = null
            pendingResult = null
            pendingFace = null
            frameInFlight.set(false)
        }
        inferenceExecutor.shutdown()
        super.onDestroy()
    }
}
