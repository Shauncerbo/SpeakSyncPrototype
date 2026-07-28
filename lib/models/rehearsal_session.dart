import 'package:hive/hive.dart';

part 'rehearsal_session.g.dart';

@HiveType(typeId: 3)
class RehearsalSession {
  const RehearsalSession({
    required this.sessionId,
    required this.userId,
    this.speechProfileId,
    required this.speechTitle,
    required this.speechType,
    required this.languageMode,
    required this.targetDurationSeconds,
    required this.durationSeconds,
    required this.sessionDate,
    required this.liveAlertsEnabled,
    required this.bodyLanguageEnabled,
    required this.fillerWordEnabled,
    required this.speakingPaceEnabled,
    required this.cameraAttentionEnabled,
  });

  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String? speechProfileId;

  @HiveField(3)
  final String speechTitle;

  @HiveField(4)
  final String speechType;

  @HiveField(5)
  final String languageMode;

  @HiveField(6)
  final int targetDurationSeconds;

  @HiveField(7)
  final int durationSeconds;

  @HiveField(8)
  final DateTime sessionDate;

  @HiveField(9)
  final bool liveAlertsEnabled;

  @HiveField(10)
  final bool bodyLanguageEnabled;

  @HiveField(11)
  final bool fillerWordEnabled;

  @HiveField(12)
  final bool speakingPaceEnabled;

  @HiveField(13)
  final bool cameraAttentionEnabled;
}
