class PracticeSettings {
  const PracticeSettings({
    required this.speechTitle,
    required this.speechType,
    required this.selectedDuration,
    required this.monitorBodyLanguage,
    required this.monitorFillers,
    required this.monitorPace,
    required this.enableLiveFeedback,
  });

  final String speechTitle;
  final String speechType;
  final String selectedDuration;
  final bool monitorBodyLanguage;
  final bool monitorFillers;
  final bool monitorPace;
  final bool enableLiveFeedback;
}
