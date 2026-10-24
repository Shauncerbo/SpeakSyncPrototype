import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/core/app_config.dart';
import 'package:speaksync_prototype/services/groq_transcription_service.dart';

void main() {
  test('build-time final model and context settings reach the service', () {
    const configuredModel = String.fromEnvironment(
      'GROQ_FINAL_TRANSCRIPTION_MODEL',
      defaultValue: 'whisper-large-v3',
    );
    const configuredContext = bool.fromEnvironment(
      'GROQ_TRANSCRIPTION_CONTEXT_ENABLED',
      defaultValue: true,
    );
    final finalService = GroqTranscriptionService.finalRecording(
      apiKey: 'test-placeholder',
      model: AppConfig.finalTranscriptionModel,
      enableContextPrompt: AppConfig.transcriptionContextEnabled,
    );
    final liveService = GroqTranscriptionService.liveFeedback(
      apiKey: 'test-placeholder',
      enableContextPrompt: AppConfig.transcriptionContextEnabled,
    );
    addTearDown(finalService.dispose);
    addTearDown(liveService.dispose);
    expect(AppConfig.transcriptionContextEnabled, configuredContext);
    expect(
      finalService.transcriptionModel,
      GroqWhisperModel.fromApiName(configuredModel),
    );
    expect(liveService.transcriptionModel, GroqWhisperModel.turbo);
    expect(finalService.timeout, const Duration(seconds: 90));
  });

  test('allowlisted model IDs support Large V3 and rollback to Turbo', () {
    expect(
      GroqWhisperModel.fromApiName('whisper-large-v3'),
      GroqWhisperModel.largeV3,
    );
    expect(
      GroqWhisperModel.fromApiName('whisper-large-v3-turbo'),
      GroqWhisperModel.turbo,
    );
    expect(
      GroqWhisperModel.fromApiName('  whisper-large-v3  '),
      GroqWhisperModel.largeV3,
    );
  });

  test('invalid or empty model configuration falls back to Turbo', () {
    for (final value in ['', 'unknown-model', 'whisper-large-v3-typo']) {
      expect(GroqWhisperModel.fromApiName(value), GroqWhisperModel.turbo);
    }
  });
}
