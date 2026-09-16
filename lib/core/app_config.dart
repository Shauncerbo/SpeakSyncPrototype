class AppConfig {
  const AppConfig._();

  static const groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  static bool get hasGroqApiKey => groqApiKey.trim().isNotEmpty;
}
