class PracticeSettings {
  const PracticeSettings({
    required this.speechTitle,
    this.speechContent,
    required this.speechType,
    required this.languageMode,
    required this.selectedDuration,
    required this.monitorBodyLanguage,
    required this.monitorCameraAttention,
    required this.monitorFillers,
    required this.monitorPace,
    required this.enableLiveFeedback,
  });

  final String speechTitle;
  final String? speechContent;
  final String speechType;
  final String languageMode;
  final String selectedDuration;
  final bool monitorBodyLanguage;
  final bool monitorCameraAttention;
  final bool monitorFillers;
  final bool monitorPace;
  final bool enableLiveFeedback;
}
