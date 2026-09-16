import '../services/speaking_pace.dart';
import '../services/filler_analysis.dart';

class PracticeSession {
  const PracticeSession({
    required this.id,
    required this.title,
    required this.speechType,
    required this.languageMode,
    required this.dateTime,
    required this.duration,
    required this.overallScore,
    required this.paceScore,
    required this.fillerScore,
    required this.postureScore,
    required this.attentionScore,
    required this.fillerCounts,
    required this.coachingTips,
    this.textTranscript,
    this.referenceScript,
    this.referenceDocumentName,
    this.omittedScriptPortions = const [],
    this.addedTranscriptPortions = const [],
    this.differentlyDeliveredPortions = const [],
    this.transcriptLines = const [],
    this.gestureCounts = const {},
    this.recommendedPosture = 'Maintain a steady upper-body posture.',
    required this.isPrototypeData,
  });

  final String id;
  final String title;
  final String speechType;
  final String languageMode;
  final DateTime dateTime;
  final Duration duration;
  final int overallScore;
  final int paceScore;
  final int fillerScore;
  final int postureScore;
  final int attentionScore;
  final Map<String, int> fillerCounts;
  final List<String> coachingTips;
  final String? textTranscript;
  final String? referenceScript;
  final String? referenceDocumentName;
  final List<String> omittedScriptPortions;
  final List<String> addedTranscriptPortions;
  final List<String> differentlyDeliveredPortions;
  final List<String> transcriptLines;
  final Map<String, int> gestureCounts;
  final String recommendedPosture;
  final bool isPrototypeData;

  // textTranscript is populated from PerformanceReport when loading history.
  SpeakingPace get speakingPace =>
      SpeakingPace.fromTranscript(textTranscript, duration);

  FillerAnalysis get fillerAnalysis =>
      FillerAnalysis.fromTranscript(textTranscript, duration);
}
