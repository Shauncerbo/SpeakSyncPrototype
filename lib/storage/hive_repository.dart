import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_preferences.dart';
import '../models/filler_word_log.dart';
import '../models/performance_report.dart';
import '../models/practice_session.dart';
import '../models/practice_settings.dart';
import '../models/rehearsal_session.dart';
import '../models/speech_profile.dart';
import '../models/user_model.dart';
import 'hive_box_names.dart';

class StorageException implements Exception {
  const StorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class HiveRepository {
  late final Box<User> _users;
  late final Box<AppPreferences> _preferences;
  late final Box<SpeechProfile> _speechProfiles;
  late final Box<RehearsalSession> _sessions;
  late final Box<FillerWordLog> _fillerLogs;
  late final Box<PerformanceReport> _reports;
  late final Box<dynamic> _metadata;

  Future<void> initializeStorage({String? storagePath}) async {
    try {
      if (storagePath == null) {
        await Hive.initFlutter();
      } else {
        Hive.init(storagePath);
      }
      _registerAdapters();
      _users = await Hive.openBox<User>(HiveBoxNames.users);
      _preferences = await Hive.openBox<AppPreferences>(
        HiveBoxNames.appPreferences,
      );
      _speechProfiles = await Hive.openBox<SpeechProfile>(
        HiveBoxNames.speechProfiles,
      );
      _sessions = await Hive.openBox<RehearsalSession>(
        HiveBoxNames.rehearsalSessions,
      );
      _fillerLogs = await Hive.openBox<FillerWordLog>(
        HiveBoxNames.fillerWordLogs,
      );
      _reports = await Hive.openBox<PerformanceReport>(
        HiveBoxNames.performanceReports,
      );
      _metadata = await Hive.openBox<dynamic>(HiveBoxNames.applicationMetadata);
      await _migrateLegacyUsers();
    } catch (error) {
      throw StorageException('Unable to initialize local storage', error);
    }
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AppPreferencesAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SpeechProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(RehearsalSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(FillerWordLogAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(PerformanceReportAdapter());
    }
  }

  Future<void> _migrateLegacyUsers() async {
    if (_metadata.get(
          StorageMetadataKeys.legacyUsersMigrated,
          defaultValue: false,
        ) ==
        true) {
      return;
    }

    try {
      if (await Hive.boxExists(HiveBoxNames.legacyUsers)) {
        final legacyBox = await Hive.openBox<User>(HiveBoxNames.legacyUsers);
        for (final user in legacyBox.values) {
          await saveUserProfile(user);
        }
        await legacyBox.close();
        await Hive.deleteBoxFromDisk(HiveBoxNames.legacyUsers);
      }
      await _metadata.put(StorageMetadataKeys.legacyUsersMigrated, true);
    } catch (error) {
      throw StorageException('Unable to migrate legacy user profiles', error);
    }
  }

  Future<void> saveUserProfile(User user) async {
    _requireId(user.userId, 'userId');
    final normalizedEmail = user.email.trim().toLowerCase();
    if (user.firstName.trim().isEmpty ||
        user.lastName.trim().isEmpty ||
        normalizedEmail.isEmpty) {
      throw const StorageException(
        'A user profile requires a first name, last name, and email',
      );
    }
    final emailIsUsed = _users.values.any(
      (existing) =>
          existing.userId != user.userId &&
          existing.email.trim().toLowerCase() == normalizedEmail,
    );
    if (emailIsUsed) {
      throw StorageException(
        'A user profile already uses the email $normalizedEmail',
      );
    }
    user.email = normalizedEmail;
    try {
      await _users.put(user.userId, user);
    } catch (error) {
      throw StorageException('Unable to save the user profile', error);
    }
  }

  User? getUserProfile([String userId = AppUserIds.demo]) => _users.get(userId);

  Future<void> savePreferences(AppPreferences preferences) async {
    _requireId(preferences.userId, 'userId');
    _requireUser(preferences.userId);
    try {
      await _preferences.put(preferences.userId, preferences);
    } catch (error) {
      throw StorageException('Unable to save application preferences', error);
    }
  }

  AppPreferences? getPreferences([String userId = AppUserIds.demo]) =>
      _preferences.get(userId);

  Future<void> saveSpeechProfile(SpeechProfile profile) async {
    _requireId(profile.speechProfileId, 'speechProfileId');
    _requireId(profile.userId, 'userId');
    _requireUser(profile.userId);
    _requireNonNegative(profile.targetDurationSeconds, 'target duration');
    try {
      await _speechProfiles.put(profile.speechProfileId, profile);
    } catch (error) {
      throw StorageException('Unable to save the speech profile', error);
    }
  }

  List<SpeechProfile> getSpeechProfiles([String userId = AppUserIds.demo]) {
    final profiles = _speechProfiles.values
        .where((profile) => profile.userId == userId)
        .toList();
    profiles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return profiles;
  }

  Future<void> saveRehearsalSession(RehearsalSession session) async {
    _validateSession(session);
    try {
      await _sessions.put(session.sessionId, session);
    } catch (error) {
      throw StorageException('Unable to save the rehearsal session', error);
    }
  }

  List<RehearsalSession> getAllRehearsalSessions([
    String userId = AppUserIds.demo,
  ]) {
    final sessions = _sessions.values
        .where((session) => session.userId == userId)
        .toList();
    sessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    return sessions;
  }

  Future<void> saveFillerWordLogs(
    String sessionId,
    List<FillerWordLog> logs,
  ) async {
    _requireSession(sessionId);
    final logIds = <String>{};
    for (final log in logs) {
      _validateFillerLog(log, sessionId);
      if (!logIds.add(log.logId)) {
        throw StorageException('Duplicate filler log ID: ${log.logId}');
      }
    }

    final existingKeys = _fillerLogs.keys
        .where((key) => _fillerLogs.get(key)?.sessionId == sessionId)
        .toList();
    try {
      await _fillerLogs.deleteAll(existingKeys);
      await _fillerLogs.putAll({for (final log in logs) log.logId: log});
    } catch (error) {
      throw StorageException('Unable to save filler-word logs', error);
    }
  }

  List<FillerWordLog> getFillerLogsBySessionId(String sessionId) {
    final logs = _fillerLogs.values
        .where((log) => log.sessionId == sessionId)
        .toList();
    logs.sort((a, b) => a.fillerWord.compareTo(b.fillerWord));
    return logs;
  }

  Future<void> savePerformanceReport(PerformanceReport report) async {
    _validateReport(report);
    final existing = getPerformanceReportBySessionId(report.sessionId);
    if (existing != null && existing.reportId != report.reportId) {
      throw StorageException(
        'Session ${report.sessionId} already has a performance report',
      );
    }
    try {
      await _reports.put(report.reportId, report);
    } catch (error) {
      throw StorageException('Unable to save the performance report', error);
    }
  }

  PerformanceReport? getPerformanceReportBySessionId(String sessionId) {
    for (final report in _reports.values) {
      if (report.sessionId == sessionId) return report;
    }
    return null;
  }

  Future<bool> saveCompletedRehearsal({
    required PracticeSession practiceSession,
    PracticeSettings? settings,
    String userId = AppUserIds.demo,
  }) async {
    if (getPerformanceReportBySessionId(practiceSession.id) != null) {
      return false;
    }

    final records = _recordsFromPracticeSession(
      practiceSession,
      settings: settings,
      userId: userId,
    );
    _validateSession(records.session, requireRelationships: false);
    for (final log in records.logs) {
      _validateFillerLog(
        log,
        records.session.sessionId,
        requireExistingSession: false,
      );
    }

    final previousProfile = _speechProfiles.get(
      records.profile.speechProfileId,
    );
    final previousSession = _sessions.get(records.session.sessionId);
    final previousLogs = getFillerLogsBySessionId(records.session.sessionId);
    final previousReport = getPerformanceReportBySessionId(
      records.session.sessionId,
    );

    try {
      await saveSpeechProfile(records.profile);
      await saveRehearsalSession(records.session);
      await saveFillerWordLogs(records.session.sessionId, records.logs);
      await savePerformanceReport(records.report);
      return true;
    } catch (error) {
      await _restoreAfterFailedSave(
        records,
        previousProfile: previousProfile,
        previousSession: previousSession,
        previousLogs: previousLogs,
        previousReport: previousReport,
      );
      if (error is StorageException) rethrow;
      throw StorageException('Unable to save the completed rehearsal', error);
    }
  }

  List<PracticeSession> getPracticeSessions([String userId = AppUserIds.demo]) {
    final result = <PracticeSession>[];
    for (final session in getAllRehearsalSessions(userId)) {
      final report = getPerformanceReportBySessionId(session.sessionId);
      if (report == null) continue;
      result.add(_toPracticeSession(session, report));
    }
    return result;
  }

  Future<void> seedDemoDataOnce({
    required List<PracticeSession> sessions,
    required AppPreferences preferences,
  }) async {
    if (_metadata.get(
          StorageMetadataKeys.demoDataSeeded,
          defaultValue: false,
        ) ==
        true) {
      return;
    }

    if (_users.get(AppUserIds.demo) == null) {
      await saveUserProfile(
        User(
          userId: AppUserIds.demo,
          firstName: 'Demo',
          lastName: 'Speaker',
          email: 'student@speaksync.local',
          createdAt: DateTime.now(),
        ),
      );
    }
    if (_preferences.get(AppUserIds.demo) == null) {
      await savePreferences(preferences);
    }

    if (_sessions.isEmpty && _reports.isEmpty) {
      for (final session in sessions) {
        await saveCompletedRehearsal(practiceSession: session);
      }
    }
    await _metadata.put(StorageMetadataKeys.demoDataSeeded, true);
  }

  Future<int> restoreDemoData({
    required List<PracticeSession> sessions,
    required AppPreferences preferences,
  }) async {
    if (_users.get(AppUserIds.demo) == null) {
      await saveUserProfile(
        User(
          userId: AppUserIds.demo,
          firstName: 'Demo',
          lastName: 'Speaker',
          email: 'student@speaksync.local',
          createdAt: DateTime.now(),
        ),
      );
    }
    if (_preferences.get(AppUserIds.demo) == null) {
      await savePreferences(preferences);
    }

    var restored = 0;
    for (final session in sessions) {
      final saved = await saveCompletedRehearsal(practiceSession: session);
      if (saved) restored++;
    }
    await _metadata.put(StorageMetadataKeys.demoDataSeeded, true);
    return restored;
  }

  Future<void> deleteSessionWithRelatedData(String sessionId) async {
    _requireId(sessionId, 'sessionId');
    final session = _sessions.get(sessionId);
    if (session == null) return;
    final reportKeys = _reports.keys
        .where((key) => _reports.get(key)?.sessionId == sessionId)
        .toList();
    final logKeys = _fillerLogs.keys
        .where((key) => _fillerLogs.get(key)?.sessionId == sessionId)
        .toList();

    try {
      await _reports.deleteAll(reportKeys);
      await _fillerLogs.deleteAll(logKeys);
      await _sessions.delete(sessionId);
      final speechProfileId = session.speechProfileId;
      if (speechProfileId != null) {
        final profileStillUsed = _sessions.values.any(
          (item) => item.speechProfileId == speechProfileId,
        );
        if (!profileStillUsed) {
          await _speechProfiles.delete(speechProfileId);
        }
      }
    } catch (error) {
      throw StorageException('Unable to delete the rehearsal session', error);
    }
  }

  Future<void> clearPrototypeData() async {
    final sessionIds = _reports.values
        .where((report) => report.isPrototypeData)
        .map((report) => report.sessionId)
        .toSet();
    try {
      for (final sessionId in sessionIds) {
        await deleteSessionWithRelatedData(sessionId);
      }
    } catch (error) {
      if (error is StorageException) rethrow;
      throw StorageException('Unable to clear prototype data', error);
    }
  }

  Future<void> _restoreAfterFailedSave(
    _PracticeRecords records, {
    required SpeechProfile? previousProfile,
    required RehearsalSession? previousSession,
    required List<FillerWordLog> previousLogs,
    required PerformanceReport? previousReport,
  }) async {
    if (previousProfile == null) {
      await _speechProfiles.delete(records.profile.speechProfileId);
    } else {
      await _speechProfiles.put(
        previousProfile.speechProfileId,
        previousProfile,
      );
    }
    if (previousSession == null) {
      await _sessions.delete(records.session.sessionId);
    } else {
      await _sessions.put(previousSession.sessionId, previousSession);
    }
    final currentLogKeys = _fillerLogs.keys
        .where(
          (key) => _fillerLogs.get(key)?.sessionId == records.session.sessionId,
        )
        .toList();
    await _fillerLogs.deleteAll(currentLogKeys);
    await _fillerLogs.putAll({for (final log in previousLogs) log.logId: log});
    if (previousReport == null) {
      await _reports.delete(records.report.reportId);
    } else {
      await _reports.put(previousReport.reportId, previousReport);
    }
  }

  _PracticeRecords _recordsFromPracticeSession(
    PracticeSession practiceSession, {
    required PracticeSettings? settings,
    required String userId,
  }) {
    _requireId(practiceSession.id, 'sessionId');
    _requireNonNegative(practiceSession.duration.inSeconds, 'duration');
    final now = DateTime.now();
    final profileId = 'speech-${practiceSession.id}';
    final targetSeconds = settings == null
        ? practiceSession.duration.inSeconds
        : _targetDurationSeconds(settings.selectedDuration);
    final transcript = practiceSession.textTranscript;
    final totalWords = _wordCount(transcript);
    final durationSeconds = practiceSession.duration.inSeconds;
    final wordsPerMinute = durationSeconds == 0
        ? 0.0
        : totalWords * 60 / durationSeconds;

    final profile = SpeechProfile(
      speechProfileId: profileId,
      userId: userId,
      speechTitle: practiceSession.title,
      speechType: practiceSession.speechType,
      languageMode: practiceSession.languageMode,
      targetDurationSeconds: targetSeconds,
      speechContent: settings?.speechContent,
      createdAt: practiceSession.dateTime,
      updatedAt: now,
    );
    final session = RehearsalSession(
      sessionId: practiceSession.id,
      userId: userId,
      speechProfileId: profileId,
      speechTitle: practiceSession.title,
      speechType: practiceSession.speechType,
      languageMode: practiceSession.languageMode,
      targetDurationSeconds: targetSeconds,
      durationSeconds: durationSeconds,
      sessionDate: practiceSession.dateTime,
      liveAlertsEnabled: settings?.enableLiveFeedback ?? true,
      bodyLanguageEnabled: settings?.monitorBodyLanguage ?? true,
      fillerWordEnabled: settings?.monitorFillers ?? true,
      speakingPaceEnabled: settings?.monitorPace ?? true,
      cameraAttentionEnabled: settings?.monitorCameraAttention ?? true,
    );
    final logs = practiceSession.fillerCounts.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => FillerWordLog(
            logId: 'log-${practiceSession.id}-${_safeIdPart(entry.key)}',
            sessionId: practiceSession.id,
            fillerWord: entry.key,
            occurrenceCount: entry.value,
            detectedTimes: _prototypeDetectionTimes(
              entry.value,
              durationSeconds,
            ),
          ),
        )
        .toList();
    final report = PerformanceReport(
      reportId: 'report-${practiceSession.id}',
      sessionId: practiceSession.id,
      totalWords: totalWords,
      wordsPerMinute: wordsPerMinute,
      paceScore: practiceSession.paceScore,
      fillerScore: practiceSession.fillerScore,
      goodPostureSeconds: (durationSeconds * practiceSession.postureScore / 100)
          .round(),
      postureScore: practiceSession.postureScore,
      cameraFacingSeconds:
          (durationSeconds * practiceSession.attentionScore / 100).round(),
      cameraScore: practiceSession.attentionScore,
      overallScore: practiceSession.overallScore,
      coachingTips: List<String>.from(practiceSession.coachingTips),
      textTranscript: transcript,
      createdAt: now,
      fillerCounts: Map<String, int>.from(practiceSession.fillerCounts),
      recommendedPosture: practiceSession.recommendedPosture,
      isPrototypeData: true,
    );
    return _PracticeRecords(
      profile: profile,
      session: session,
      logs: logs,
      report: report,
    );
  }

  PracticeSession _toPracticeSession(
    RehearsalSession session,
    PerformanceReport report,
  ) {
    return PracticeSession(
      id: session.sessionId,
      title: session.speechTitle,
      speechType: session.speechType,
      languageMode: session.languageMode,
      dateTime: session.sessionDate,
      duration: Duration(seconds: session.durationSeconds),
      overallScore: report.overallScore,
      paceScore: report.paceScore,
      fillerScore: report.fillerScore,
      postureScore: report.postureScore,
      attentionScore: report.cameraScore,
      fillerCounts: Map<String, int>.unmodifiable(report.fillerCounts),
      coachingTips: List<String>.unmodifiable(report.coachingTips),
      textTranscript: report.textTranscript,
      recommendedPosture: report.recommendedPosture,
      isPrototypeData: report.isPrototypeData,
    );
  }

  void _validateSession(
    RehearsalSession session, {
    bool requireRelationships = true,
  }) {
    _requireId(session.sessionId, 'sessionId');
    _requireId(session.userId, 'userId');
    final speechProfileId = session.speechProfileId;
    if (speechProfileId != null) {
      _requireId(speechProfileId, 'speechProfileId');
    }
    _requireNonNegative(session.targetDurationSeconds, 'target duration');
    _requireNonNegative(session.durationSeconds, 'duration');
    if (!requireRelationships) return;

    _requireUser(session.userId);
    if (speechProfileId == null) return;
    final profile = _requireSpeechProfile(speechProfileId);
    if (profile.userId != session.userId) {
      throw StorageException(
        'Rehearsal session ${session.sessionId} and speech profile '
        '${profile.speechProfileId} must belong to the same user',
      );
    }
  }

  void _validateFillerLog(
    FillerWordLog log,
    String expectedSessionId, {
    bool requireExistingSession = true,
  }) {
    _requireId(log.logId, 'logId');
    if (log.sessionId != expectedSessionId) {
      throw const StorageException(
        'A filler log must reference its rehearsal session',
      );
    }
    if (requireExistingSession) _requireSession(log.sessionId);
    _requireNonNegative(log.occurrenceCount, 'occurrence count');
    if (log.occurrenceCount != log.detectedTimes.length) {
      throw StorageException(
        'Filler log ${log.logId} has an occurrence count that does not match '
        'its detected times',
      );
    }
    if (log.detectedTimes.any((time) => time < 0)) {
      throw StorageException(
        'Filler log ${log.logId} contains a negative detection time',
      );
    }
  }

  void _validateReport(PerformanceReport report) {
    _requireId(report.reportId, 'reportId');
    _requireSession(report.sessionId);
    _requireNonNegative(report.totalWords, 'total words');
    if (report.wordsPerMinute < 0) {
      throw const StorageException('Words per minute cannot be negative');
    }
    _requireScore(report.paceScore, 'pace score');
    _requireScore(report.fillerScore, 'filler score');
    _requireScore(report.postureScore, 'posture score');
    _requireScore(report.cameraScore, 'camera score');
    _requireScore(report.overallScore, 'overall score');
    _requireNonNegative(report.goodPostureSeconds, 'good-posture duration');
    _requireNonNegative(report.cameraFacingSeconds, 'camera-facing duration');
  }

  void _requireSession(String sessionId) {
    if (!_sessions.containsKey(sessionId)) {
      throw StorageException(
        'Referenced rehearsal session does not exist: $sessionId',
      );
    }
  }

  User _requireUser(String userId) {
    final user = _users.get(userId);
    if (user == null) {
      throw StorageException('Referenced user profile does not exist: $userId');
    }
    return user;
  }

  SpeechProfile _requireSpeechProfile(String speechProfileId) {
    final profile = _speechProfiles.get(speechProfileId);
    if (profile == null) {
      throw StorageException(
        'Referenced speech profile does not exist: $speechProfileId',
      );
    }
    return profile;
  }

  void _requireId(String value, String field) {
    if (value.trim().isEmpty) {
      throw StorageException('$field cannot be empty');
    }
  }

  void _requireNonNegative(int value, String field) {
    if (value < 0) throw StorageException('$field cannot be negative');
  }

  void _requireScore(int value, String field) {
    if (value < 0 || value > 100) {
      throw StorageException('$field must be between 0 and 100');
    }
  }

  int _targetDurationSeconds(String value) {
    final match = RegExp(r'^(\d+)').firstMatch(value);
    if (match == null) return 0;
    return int.parse(match.group(1)!) * 60;
  }

  int _wordCount(String? transcript) {
    if (transcript == null || transcript.trim().isEmpty) return 0;
    return transcript.trim().split(RegExp(r'\s+')).length;
  }

  String _safeIdPart(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  List<int> _prototypeDetectionTimes(int count, int durationSeconds) {
    if (count <= 0) return const [];
    return List<int>.generate(
      count,
      (index) => durationSeconds == 0
          ? 0
          : ((index + 1) * durationSeconds / (count + 1)).round(),
    );
  }
}

class _PracticeRecords {
  const _PracticeRecords({
    required this.profile,
    required this.session,
    required this.logs,
    required this.report,
  });

  final SpeechProfile profile;
  final RehearsalSession session;
  final List<FillerWordLog> logs;
  final PerformanceReport report;
}
