import 'package:hive/hive.dart';

part 'app_preferences.g.dart';

@HiveType(typeId: 1)
class AppPreferences {
  const AppPreferences({
    required this.userId,
    required this.defaultLanguage,
    required this.defaultDuration,
    required this.liveFeedback,
    required this.bodyMonitoring,
    required this.cameraAttentionMonitoring,
    required this.fillerMonitoring,
    required this.paceMonitoring,
    required this.alertFrequency,
  });

  @HiveField(0)
  final String userId;

  @HiveField(1)
  final String defaultLanguage;

  @HiveField(2)
  final String defaultDuration;

  @HiveField(3)
  final bool liveFeedback;

  @HiveField(4)
  final bool bodyMonitoring;

  @HiveField(5)
  final bool cameraAttentionMonitoring;

  @HiveField(6)
  final bool fillerMonitoring;

  @HiveField(7)
  final bool paceMonitoring;

  @HiveField(8)
  final String alertFrequency;

  AppPreferences copyWith({
    String? userId,
    String? defaultLanguage,
    String? defaultDuration,
    bool? liveFeedback,
    bool? bodyMonitoring,
    bool? cameraAttentionMonitoring,
    bool? fillerMonitoring,
    bool? paceMonitoring,
    String? alertFrequency,
  }) {
    return AppPreferences(
      userId: userId ?? this.userId,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      defaultDuration: defaultDuration ?? this.defaultDuration,
      liveFeedback: liveFeedback ?? this.liveFeedback,
      bodyMonitoring: bodyMonitoring ?? this.bodyMonitoring,
      cameraAttentionMonitoring:
          cameraAttentionMonitoring ?? this.cameraAttentionMonitoring,
      fillerMonitoring: fillerMonitoring ?? this.fillerMonitoring,
      paceMonitoring: paceMonitoring ?? this.paceMonitoring,
      alertFrequency: alertFrequency ?? this.alertFrequency,
    );
  }
}
