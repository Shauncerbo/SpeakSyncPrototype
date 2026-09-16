import 'package:hive/hive.dart';

part 'speech_profile.g.dart';

@HiveType(typeId: 2)
class SpeechProfile {
  const SpeechProfile({
    required this.speechProfileId,
    required this.userId,
    required this.speechTitle,
    required this.speechType,
    required this.languageMode,
    required this.targetDurationSeconds,
    required this.speechContent,
    this.sourceDocumentName,
    required this.createdAt,
    required this.updatedAt,
  });

  @HiveField(0)
  final String speechProfileId;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String speechTitle;

  @HiveField(3)
  final String speechType;

  @HiveField(4)
  final String languageMode;

  @HiveField(5)
  final int targetDurationSeconds;

  @HiveField(6)
  final String? speechContent;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  @HiveField(9)
  final String? sourceDocumentName;
}
