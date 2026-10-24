import '../services/groq_transcription_service.dart';

class AppConfig {
  const AppConfig._();

  static const groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  static const _finalTranscriptionModel = String.fromEnvironment(
    'GROQ_FINAL_TRANSCRIPTION_MODEL',
    defaultValue: 'whisper-large-v3',
  );

  static GroqWhisperModel get finalTranscriptionModel =>
      GroqWhisperModel.fromApiName(_finalTranscriptionModel);

  static const transcriptionContextEnabled = bool.fromEnvironment(
    'GROQ_TRANSCRIPTION_CONTEXT_ENABLED',
    defaultValue: true,
  );

  static bool get hasGroqApiKey => groqApiKey.trim().isNotEmpty;
}
