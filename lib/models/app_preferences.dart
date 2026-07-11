class AppPreferences {
  const AppPreferences({
    required this.defaultLanguage,
    required this.defaultDuration,
    required this.liveFeedback,
    required this.vibrationFeedback,
    required this.bodyMonitoring,
    required this.cameraAttentionMonitoring,
    required this.fillerMonitoring,
    required this.paceMonitoring,
    required this.alertFrequency,
  });

  final String defaultLanguage;
  final String defaultDuration;
  final bool liveFeedback;
  final bool vibrationFeedback;
  final bool bodyMonitoring;
  final bool cameraAttentionMonitoring;
  final bool fillerMonitoring;
  final bool paceMonitoring;
  final String alertFrequency;

  AppPreferences copyWith({
    String? defaultLanguage,
    String? defaultDuration,
    bool? liveFeedback,
    bool? vibrationFeedback,
    bool? bodyMonitoring,
    bool? cameraAttentionMonitoring,
    bool? fillerMonitoring,
    bool? paceMonitoring,
    String? alertFrequency,
  }) {
    return AppPreferences(
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      defaultDuration: defaultDuration ?? this.defaultDuration,
      liveFeedback: liveFeedback ?? this.liveFeedback,
      vibrationFeedback: vibrationFeedback ?? this.vibrationFeedback,
      bodyMonitoring: bodyMonitoring ?? this.bodyMonitoring,
      cameraAttentionMonitoring:
          cameraAttentionMonitoring ?? this.cameraAttentionMonitoring,
      fillerMonitoring: fillerMonitoring ?? this.fillerMonitoring,
      paceMonitoring: paceMonitoring ?? this.paceMonitoring,
      alertFrequency: alertFrequency ?? this.alertFrequency,
    );
  }
}
