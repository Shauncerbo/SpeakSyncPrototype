import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordingException implements Exception {
  const AudioRecordingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RehearsalAudioRecorder {
  RehearsalAudioRecorder({
    AudioRecorder? recorder,
    Future<Directory> Function()? temporaryDirectory,
  }) : _recorder = recorder ?? AudioRecorder(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final AudioRecorder _recorder;
  final Future<Directory> Function() _temporaryDirectory;
  String? _recordingPath;
  bool _started = false;

  bool get hasStarted => _started;

  /// Current input volume from the same recorder used for transcription.
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((amplitude) => levelFromDecibels(amplitude.current));

  static double levelFromDecibels(double decibels) {
    // Suppress quiet room noise; this measures volume, not speech recognition.
    if (!decibels.isFinite || decibels <= -50) return 0;
    return ((decibels + 50) / 40).clamp(0.0, 1.0);
  }

  Future<void> start() async {
    if (_started) return;
    if (!await _recorder.hasPermission()) {
      throw const AudioRecordingException(
        'Microphone permission is required to transcribe the rehearsal.',
      );
    }

    try {
      final directory = await _temporaryDirectory();
      final path =
          '${directory.path}${Platform.pathSeparator}'
          'speaksync-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _recordingPath = path;
      _started = true;
    } catch (_) {
      throw const AudioRecordingException(
        'SpeakSync could not start microphone recording.',
      );
    }
  }

  Future<void> pause() async {
    if (!_started) return;
    await _recorder.pause();
  }

  Future<void> resume() async {
    if (!_started) return;
    await _recorder.resume();
  }

  Future<String?> stop() async {
    if (!_started) return null;
    try {
      final path = await _recorder.stop();
      _started = false;
      return path ?? _recordingPath;
    } catch (_) {
      _started = false;
      throw const AudioRecordingException(
        'SpeakSync could not finish the microphone recording.',
      );
    }
  }

  Future<void> cancel() async {
    if (!_started) return;
    try {
      await _recorder.cancel();
    } finally {
      _started = false;
      await deleteTemporaryFile(_recordingPath);
    }
  }

  /// Wait for native recording shutdown before another recording is started.
  /// Android's cancel acknowledgement can precede encoder/thread shutdown.
  Future<void> discard() async {
    final path = await stop();
    await deleteTemporaryFile(path);
    _recordingPath = null;
  }

  Future<void> deleteTemporaryFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Temporary files are also managed by the operating system cache.
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
