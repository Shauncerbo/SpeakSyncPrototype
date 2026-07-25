import 'package:hive/hive.dart';

part 'performance_report.g.dart';

@HiveType(typeId: 5)
class PerformanceReport {
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
  });

  @HiveField(0)
  final String reportId;

  @HiveField(1)
  final String sessionId;

  @HiveField(2)
  final int totalWords;

  @HiveField(3)
  final double wordsPerMinute;

  @HiveField(4)
  final int paceScore;

  @HiveField(5)
  final int fillerScore;

  @HiveField(6)
  final int goodPostureSeconds;

  @HiveField(7)
  final int postureScore;

  @HiveField(8)
  final int cameraFacingSeconds;

  @HiveField(9)
  final int cameraScore;

  @HiveField(10)
  final int overallScore;

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
}
