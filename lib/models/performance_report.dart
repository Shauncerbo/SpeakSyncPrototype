import 'package:hive/hive.dart';

part 'performance_report.g.dart';

@HiveType(typeId: 5)
class PerformanceReport {
  // Field IDs stay stable. Null means unavailable/unvalidated, not zero.
  // Old numeric values remain readable, but do not establish score validity.
  const PerformanceReport({
    required this.reportId,
    required this.sessionId,
    required this.totalWords,
    required this.wordsPerMinute,
    required this.paceScore,
    required this.fillerScore,
    required this.goodPostureSeconds,
    required this.postureScore,
    required this.cameraFacingSeconds,
    required this.cameraScore,
    required this.overallScore,
    required this.coachingTips,
    required this.textTranscript,
    required this.createdAt,
    required this.fillerCounts,
    required this.recommendedPosture,
    required this.isPrototypeData,
    this.referenceScript,
    this.referenceDocumentName,
    this.omittedScriptPortions = const [],
    this.addedTranscriptPortions = const [],
    this.differentlyDeliveredPortions = const [],
    this.totalScriptWords,
    this.matchedScriptWords,
    this.scriptComparisonStatus,
    this.validPostureSeconds,
    this.validFaceAnalysisMilliseconds,
    this.cameraFramingMilliseconds,
  });

  @HiveField(0)
  final String reportId;

  @HiveField(1)
  final String sessionId;

  @HiveField(2)
  final int totalWords;

  @HiveField(3)
  final double? wordsPerMinute;

  @HiveField(4)
  final int? paceScore;

  @HiveField(5)
  final int? fillerScore;

  @HiveField(6)
  final int? goodPostureSeconds;

  @HiveField(7)
  /// Pose-derived acceptable-time percentage when coverage is sufficient.
  /// This is not a validated educational performance score.
  final int? postureScore;

  @HiveField(8)
  final int? cameraFacingSeconds;

  @HiveField(9)
  final int? cameraScore;

  @HiveField(10)
  final int? overallScore;

  @HiveField(11)
  final List<String> coachingTips;

  @HiveField(12)
  final String? textTranscript;

  @HiveField(13)
  final DateTime createdAt;

  @HiveField(14)
  final Map<String, int> fillerCounts;

  @HiveField(15)
  final String recommendedPosture;

  @HiveField(16)
  final bool isPrototypeData;

  @HiveField(17)
  final String? referenceScript;

  @HiveField(18)
  final String? referenceDocumentName;

  @HiveField(19, defaultValue: <String>[])
  final List<String> omittedScriptPortions;

  @HiveField(20, defaultValue: <String>[])
  final List<String> addedTranscriptPortions;

  @HiveField(21, defaultValue: <String>[])
  final List<String> differentlyDeliveredPortions;

  @HiveField(22)
  final int? totalScriptWords;

  @HiveField(23)
  final int? matchedScriptWords;

  @HiveField(24)
  final String? scriptComparisonStatus;

  /// Total rehearsal time backed by sufficiently visible pose landmarks.
  /// Null identifies reports saved before on-device posture analysis existed.
  @HiveField(25)
  final int? validPostureSeconds;

  /// Null for legacy/unmeasured attention. Provenance and the valid-time
  /// denominator for head-orientation estimates (not eye contact or a score).
  @HiveField(26)
  final int? validFaceAnalysisMilliseconds;

  /// Valid intervals of the existing pose-derived framing classifications.
  /// Null for legacy records; unavailable/gapped frames are never counted.
  @HiveField(27)
  final Map<String, int>? cameraFramingMilliseconds;
}
