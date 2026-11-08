import 'dart:async';
import 'dart:typed_data';

import 'package:speaksync_prototype/services/groq_transcription_service.dart';
import 'package:speaksync_prototype/services/rehearsal_audio_recorder.dart';

class SuccessfulRehearsalAudioRecorder implements RehearsalAudioRecorder {
  bool _started = false;
  final _chunks = StreamController<Uint8List>.broadcast();
  final _levels = StreamController<double>.broadcast();

  @override
  bool get hasStarted => _started;

  @override
  Duration get chunkDuration => RehearsalAudioRecorder.defaultLiveChunkDuration;

  @override
  Stream<Uint8List> get chunks => _chunks.stream;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<void> start({bool enableLiveChunks = false}) async {
    _started = true;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async {
    _started = false;
    return null;
  }

  @override
  Future<void> discard() async {
    _started = false;
  }

  @override
  Future<void> cancel() async {
    _started = false;
  }

  @override
  Future<void> deleteTemporaryFile(String? path) async {}

  @override
  Future<void> dispose() async {
    _started = false;
    await _chunks.close();
    await _levels.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubGroqTranscriptionService extends GroqTranscriptionService {
  StubGroqTranscriptionService() : super(apiKey: 'test-placeholder');

  @override
  Future<String> transcribe(String audioPath) async => '';
}
