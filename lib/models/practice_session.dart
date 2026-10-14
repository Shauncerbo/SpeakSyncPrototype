import '../services/speaking_pace.dart';
import '../services/filler_analysis.dart';
import '../services/script_comparison_service.dart';
import '../services/measurement_coaching.dart';

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
    this.totalScriptWords,
    this.matchedScriptWords,
    this.scriptComparisonStatus,
    this.goodPostureSeconds,
    this.validPostureSeconds,
    this.cameraFacingSeconds,
    this.validFaceAnalysisMilliseconds,
    this.cameraFramingMilliseconds,
    this.monitorPace = true,
    this.monitorFillers = true,
    this.monitorBodyLanguage = true,
    this.monitorCameraAttention = true,
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
  final int? overallScore;
  final int? paceScore;
  final int? fillerScore;
  final int? postureScore;
  final int? attentionScore;
  final Map<String, int> fillerCounts;
  final List<String> coachingTips;
  final String? textTranscript;
  final String? referenceScript;
  final String? referenceDocumentName;
  final List<String> omittedScriptPortions;
  final List<String> addedTranscriptPortions;
  final List<String> differentlyDeliveredPortions;
  final int? totalScriptWords;
  final int? matchedScriptWords;
  final String? scriptComparisonStatus;
  final int? goodPostureSeconds;
  final int? validPostureSeconds;
  final int? cameraFacingSeconds;
  final int? validFaceAnalysisMilliseconds;
  final Map<String, int>? cameraFramingMilliseconds;
  final bool monitorPace;
  final bool monitorFillers;
  final bool monitorBodyLanguage;
  final bool monitorCameraAttention;

  bool get postureAnalysisUnavailable =>
      !monitorBodyLanguage ||
      isDemoSession ||
      postureScore == null ||
      postureScore! < 0 ||
      postureScore! > 100 ||
      validPostureSeconds == null ||
      validPostureSeconds! < 3;

  /// No validated overall, pace, or filler scoring policy exists yet.
  int? get validatedOverallScore => null;

  /// Head-facing time fraction only. Old numeric camera scores without face
  /// coverage provenance are legacy values, never new valid measurements.
  int? get measuredAttentionPercentage =>
      validFaceAnalysisMilliseconds != null &&
          monitorCameraAttention &&
          !isDemoSession &&
          validFaceAnalysisMilliseconds! >= 3000 &&
          cameraFacingSeconds != null &&
          cameraFacingSeconds! >= 0 &&
          cameraFacingSeconds! * 1000 <= validFaceAnalysisMilliseconds! &&
          attentionScore != null &&
          attentionScore! >= 0 &&
          attentionScore! <= 100
      ? attentionScore
      : null;

  /// A pose-derived time fraction, not a validated 0–100 educational score.
  int? get measuredPosturePercentage =>
      postureAnalysisUnavailable ? null : postureScore;

  /// The bundled examples use stable IDs; actual rehearsals use session-* IDs.
  bool get isDemoSession => id.startsWith('initial-');

  /// Derive suggestions from final measured data, never legacy score-based tips.
  List<String> get measuredCoachingTips => measuredCoachingTipsFor();

  List<String> measuredCoachingTipsFor({
    bool? includePace,
    bool? includeFillers,
    bool? includePosture,
    bool? includeCameraFacing,
  }) => MeasurementCoaching.generate(
    pace: speakingPace,
    fillers: fillerAnalysis,
    posturePercentage: measuredPosturePercentage,
    validPostureSeconds: validPostureSeconds,
    facingPercentage: measuredAttentionPercentage,
    validFaceMilliseconds: validFaceAnalysisMilliseconds,
    framingMilliseconds: cameraFramingMilliseconds,
    monitorPace: includePace ?? monitorPace,
    monitorFillers: includeFillers ?? monitorFillers,
    monitorPosture: includePosture ?? monitorBodyLanguage,
    monitorFacing: includeCameraFacing ?? monitorCameraAttention,
    demo: isDemoSession,
  );

  String get postureCoachingRecommendation => !monitorBodyLanguage
      ? 'Upper-body monitoring was off for this rehearsal.'
      : isDemoSession
      ? 'Example rehearsal: no verified posture analysis.'
      : MeasurementCoaching.posture(
          measuredPosturePercentage,
          validPostureSeconds,
        );

  bool get hasScriptComparison =>
      ScriptComparisonService.supports(speechType) &&
      referenceScript?.trim().isNotEmpty == true;

  ScriptComparisonResult? get scriptComparison {
    if (!hasScriptComparison) return null;
    // Old reports contain both source texts but no word-level coverage fields.
    if (scriptComparisonStatus == null) {
      return const ScriptComparisonService().compare(
        referenceScript: referenceScript,
        transcript: textTranscript,
      );
    }
    return ScriptComparisonResult(
      status: scriptComparisonStatus!,
      totalReferenceWords: totalScriptWords ?? 0,
      matchedReferenceWords: matchedScriptWords ?? 0,
      omittedPortions: omittedScriptPortions,
      addedPortions: addedTranscriptPortions,
      differentlyDeliveredPortions: differentlyDeliveredPortions,
    );
  }

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
