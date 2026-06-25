class AppPreferences {
  const AppPreferences({
    required this.defaultDuration,
    required this.liveFeedback,
    required this.vibrationFeedback,
    required this.bodyMonitoring,
    required this.fillerMonitoring,
  });

  final String defaultDuration;
  final bool liveFeedback;
  final bool vibrationFeedback;
  final bool bodyMonitoring;
  final bool fillerMonitoring;

  AppPreferences copyWith({
    String? defaultDuration,
    bool? liveFeedback,
    bool? vibrationFeedback,
    bool? bodyMonitoring,
    bool? fillerMonitoring,
  }) {
    return AppPreferences(
      defaultDuration: defaultDuration ?? this.defaultDuration,
      liveFeedback: liveFeedback ?? this.liveFeedback,
      vibrationFeedback: vibrationFeedback ?? this.vibrationFeedback,
      bodyMonitoring: bodyMonitoring ?? this.bodyMonitoring,
      fillerMonitoring: fillerMonitoring ?? this.fillerMonitoring,
    );
  }
}
