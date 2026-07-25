import 'package:hive/hive.dart';

part 'filler_word_log.g.dart';

@HiveType(typeId: 4)
class FillerWordLog {
  const FillerWordLog({
    required this.logId,
    required this.sessionId,
    required this.fillerWord,
    required this.occurrenceCount,
    required this.detectedTimes,
  });

  @HiveField(0)
  final String logId;

  @HiveField(1)
  final String sessionId;

  @HiveField(2)
  final String fillerWord;

  @HiveField(3)
  final int occurrenceCount;

  @HiveField(4)
  final List<int> detectedTimes;
}
