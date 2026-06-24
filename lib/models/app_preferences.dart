class AppPreferences {
  const AppPreferences({
    required this.defaultLanguage,
    required this.defaultDuration,
    required this.liveFeedback,
    required this.vibrationFeedback,
    required this.bodyMonitoring,
    required this.fillerMonitoring,
  });

  final String defaultLanguage;
  final String defaultDuration;
  final bool liveFeedback;
  final bool vibrationFeedback;
  final bool bodyMonitoring;
  final bool fillerMonitoring;

  AppPreferences copyWith({
    String? defaultLanguage,
    String? defaultDuration,
    bool? liveFeedback,
    bool? vibrationFeedback,
    bool? bodyMonitoring,
    bool? fillerMonitoring,
  }) {
    return AppPreferences(
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      defaultDuration: defaultDuration ?? this.defaultDuration,
      liveFeedback: liveFeedback ?? this.liveFeedback,
      vibrationFeedback: vibrationFeedback ?? this.vibrationFeedback,
      bodyMonitoring: bodyMonitoring ?? this.bodyMonitoring,
      fillerMonitoring: fillerMonitoring ?? this.fillerMonitoring,
    );
  }
}
