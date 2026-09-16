import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:speaksync_prototype/data/dummy_data.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/models/practice_settings.dart';
import 'package:speaksync_prototype/models/rehearsal_session.dart';
import 'package:speaksync_prototype/models/speech_profile.dart';
import 'package:speaksync_prototype/models/user_model.dart';
import 'package:speaksync_prototype/state/app_state.dart';
import 'package:speaksync_prototype/storage/hive_repository.dart';

void main() {
  late Directory storageDirectory;

  setUp(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'speaksync-hive-test-',
    );
  });

  tearDown(() async {
    await Hive.close();
    if (await storageDirectory.exists()) {
      await storageDirectory.delete(recursive: true);
    }
  });

  test(
    'persists reports, settings, prevents duplicates, and clears safely',
    () async {
      var repository = HiveRepository();
      await repository.initializeStorage(storagePath: storageDirectory.path);
      await repository.seedDemoDataOnce(
        sessions: initialSessions(),
        preferences: initialPreferences,
      );

      expect(repository.getPracticeSessions(), hasLength(4));

      final updatedPreferences = initialPreferences.copyWith(
        defaultDuration: '5 minutes',
        liveFeedback: false,
      );
      await repository.savePreferences(updatedPreferences);

      final completed = PracticeSession(
        id: 'persisted-test-session',
        title: 'Persisted Test Speech',
        speechType: 'Prepared',
        languageMode: 'Mixed Language',
        dateTime: DateTime(2026, 7, 24, 12),
        duration: const Duration(minutes: 2),
        overallScore: 88,
        paceScore: 90,
        fillerScore: 86,
        postureScore: 89,
        attentionScore: 87,
        fillerCounts: const {'Kuan': 2},
        coachingTips: const ['Keep using purposeful pauses.'],
        textTranscript: 'Kuan kuan persisted prototype transcript.',
        isPrototypeData: true,
      );
      const setup = PracticeSettings(
        speechTitle: 'Persisted Test Speech',
        speechContent: 'A short persisted prototype reference script.',
        referenceDocumentName: 'persisted-test-speech.txt',
        speechType: 'Prepared',
        languageMode: 'Mixed Language',
        selectedDuration: '3 minutes',
        monitorBodyLanguage: true,
        monitorCameraAttention: true,
        monitorFillers: true,
        monitorPace: true,
        enableLiveFeedback: false,
      );

      expect(
        await repository.saveCompletedRehearsal(
          practiceSession: completed,
          settings: setup,
        ),
        isTrue,
      );
      expect(
        await repository.saveCompletedRehearsal(
          practiceSession: completed,
          settings: setup,
        ),
        isFalse,
      );
      expect(repository.getPracticeSessions(), hasLength(5));
      expect(
        repository.getPerformanceReportBySessionId(completed.id)?.overallScore,
        88,
      );
      final logs = repository.getFillerLogsBySessionId(completed.id);
      expect(logs, hasLength(1));
      expect(logs.single.fillerWord, 'kuan');
      expect(logs.single.occurrenceCount, 2);
      expect(logs.single.detectedTimes, isEmpty);
      expect(logs.single.transcriptOffsets, [0, 5]);

      await Hive.close();
      repository = HiveRepository();
      await repository.initializeStorage(storagePath: storageDirectory.path);
      await repository.seedDemoDataOnce(
        sessions: initialSessions(),
        preferences: initialPreferences,
      );

      expect(repository.getPracticeSessions(), hasLength(5));
      expect(repository.getPreferences()?.defaultDuration, '5 minutes');
      expect(repository.getPreferences()?.liveFeedback, isFalse);

      // The actual rehearsal lasted two minutes, although setup targeted three.
      final savedReport = repository.getPerformanceReportBySessionId(
        completed.id,
      )!;
      expect(savedReport.textTranscript, completed.textTranscript);
      expect(savedReport.totalWords, 5);
      expect(savedReport.wordsPerMinute, 2.5);
      expect(savedReport.fillerCounts, {'kuan': 2});
      expect(
        repository
            .getFillerLogsBySessionId(completed.id)
            .single
            .transcriptOffsets,
        [0, 5],
      );
      expect(savedReport.paceScore, completed.paceScore);
      expect(savedReport.overallScore, completed.overallScore);
      final reloaded = repository.getPracticeSessions().singleWhere(
        (session) => session.id == completed.id,
      );
      expect(reloaded.speakingPace.totalWords, savedReport.totalWords);
      expect(reloaded.speakingPace.wordsPerMinute, savedReport.wordsPerMinute);
      expect(reloaded.speakingPace.classification, 'Slow');

      await repository.clearPrototypeData();
      expect(repository.getPracticeSessions(), isEmpty);
      expect(repository.getPerformanceReportBySessionId(completed.id), isNull);
      expect(repository.getFillerLogsBySessionId(completed.id), isEmpty);

      expect(
        await repository.restoreDemoData(
          sessions: initialSessions(),
          preferences: initialPreferences,
        ),
        4,
      );
      expect(repository.getPracticeSessions(), hasLength(4));
      expect(
        await repository.restoreDemoData(
          sessions: initialSessions(),
          preferences: initialPreferences,
        ),
        0,
      );
      expect(repository.getPracticeSessions(), hasLength(4));
    },
  );

  test('AppState saves and reloads the UI session aggregate', () async {
    var repository = HiveRepository();
    await repository.initializeStorage(storagePath: storageDirectory.path);
    var state = AppState(repository: repository);
    await state.initialize();
    const setup = PracticeSettings(
      speechTitle: 'AppState Speech',
      speechContent: 'This is the prepared speech script.',
      speechType: 'Prepared',
      languageMode: 'English',
      selectedDuration: '1 minute',
      monitorBodyLanguage: true,
      monitorCameraAttention: true,
      monitorFillers: true,
      monitorPace: true,
      enableLiveFeedback: true,
    );
    state.setCurrentSetup(setup);
    state.setCurrentReport(
      PracticeSession(
        id: 'app-state-persisted-session',
        title: setup.speechTitle,
        speechType: setup.speechType,
        languageMode: setup.languageMode,
        dateTime: DateTime(2026, 7, 24, 13),
        duration: const Duration(seconds: 50),
        overallScore: 91,
        paceScore: 93,
        fillerScore: 90,
        postureScore: 92,
        attentionScore: 89,
        fillerCounts: const {'Ano': 1},
        coachingTips: const ['Keep your ending concise.'],
        textTranscript: 'Ano, this report is saved through AppState.',
        isPrototypeData: true,
      ),
    );

    expect(await state.saveCurrentReport(), isTrue);
    expect(
      state.sessions.where((item) => item.id == 'app-state-persisted-session'),
      hasLength(1),
    );

    await Hive.close();
    repository = HiveRepository();
    await repository.initializeStorage(storagePath: storageDirectory.path);
    state = AppState(repository: repository);
    await state.initialize();

    final restored = state.sessions.singleWhere(
      (item) => item.id == 'app-state-persisted-session',
    );
    expect(restored.overallScore, 91);
    expect(restored.fillerCounts, const {'ano': 1});
    expect(
      repository
          .getSpeechProfiles()
          .singleWhere(
            (profile) =>
                profile.speechProfileId == 'speech-app-state-persisted-session',
          )
          .speechContent,
      'This is the prepared speech script.',
    );
  });

  test(
    'enforces user, profile, ownership, and unique-email relationships',
    () async {
      final repository = HiveRepository();
      await repository.initializeStorage(storagePath: storageDirectory.path);

      await expectLater(
        repository.savePreferences(
          initialPreferences.copyWith(userId: 'missing-user'),
        ),
        throwsA(isA<StorageException>()),
      );

      final userA = User(
        userId: 'user-a',
        firstName: 'User',
        lastName: 'A',
        email: 'USER@EXAMPLE.COM',
        createdAt: DateTime(2026, 7, 24),
      );
      await repository.saveUserProfile(userA);
      expect(repository.getUserProfile('user-a')?.email, 'user@example.com');

      await expectLater(
        repository.saveUserProfile(
          User(
            userId: 'duplicate-email-user',
            firstName: 'Duplicate',
            lastName: 'Email',
            email: 'user@example.com',
            createdAt: DateTime(2026, 7, 24),
          ),
        ),
        throwsA(isA<StorageException>()),
      );

      final userB = User(
        userId: 'user-b',
        firstName: 'User',
        lastName: 'B',
        email: 'user-b@example.com',
        createdAt: DateTime(2026, 7, 24),
      );
      await repository.saveUserProfile(userB);

      await expectLater(
        repository.saveSpeechProfile(
          SpeechProfile(
            speechProfileId: 'missing-user-profile',
            userId: 'missing-user',
            speechTitle: 'Missing User',
            speechType: 'Prepared',
            languageMode: 'English',
            targetDurationSeconds: 60,
            speechContent: null,
            createdAt: DateTime(2026, 7, 24),
            updatedAt: DateTime(2026, 7, 24),
          ),
        ),
        throwsA(isA<StorageException>()),
      );

      final profileA = SpeechProfile(
        speechProfileId: 'profile-a',
        userId: userA.userId,
        speechTitle: 'Profile A',
        speechType: 'Prepared',
        languageMode: 'English',
        targetDurationSeconds: 60,
        speechContent: 'Prepared content.',
        createdAt: DateTime(2026, 7, 24),
        updatedAt: DateTime(2026, 7, 24),
      );
      await repository.saveSpeechProfile(profileA);

      RehearsalSession session({
        required String sessionId,
        required String userId,
        String? speechProfileId,
      }) {
        return RehearsalSession(
          sessionId: sessionId,
          userId: userId,
          speechProfileId: speechProfileId,
          speechTitle: 'Relationship Test',
          speechType: speechProfileId == null ? 'Impromptu' : 'Prepared',
          languageMode: 'English',
          targetDurationSeconds: 60,
          durationSeconds: 45,
          sessionDate: DateTime(2026, 7, 24),
          liveAlertsEnabled: true,
          bodyLanguageEnabled: true,
          fillerWordEnabled: true,
          speakingPaceEnabled: true,
          cameraAttentionEnabled: true,
        );
      }

      await expectLater(
        repository.saveRehearsalSession(
          session(
            sessionId: 'missing-profile-session',
            userId: userA.userId,
            speechProfileId: 'missing-profile',
          ),
        ),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        repository.saveRehearsalSession(
          session(
            sessionId: 'wrong-owner-session',
            userId: userB.userId,
            speechProfileId: profileA.speechProfileId,
          ),
        ),
        throwsA(isA<StorageException>()),
      );

      await repository.saveRehearsalSession(
        session(
          sessionId: 'valid-session',
          userId: userA.userId,
          speechProfileId: profileA.speechProfileId,
        ),
      );
      expect(
        repository.getAllRehearsalSessions(userA.userId).single.speechProfileId,
        profileA.speechProfileId,
      );

      await repository.saveRehearsalSession(
        session(sessionId: 'session-without-profile', userId: userA.userId),
      );
      expect(
        repository
            .getAllRehearsalSessions(userA.userId)
            .any((item) => item.sessionId == 'session-without-profile'),
        isTrue,
      );
      await repository.deleteSessionWithRelatedData('session-without-profile');
    },
  );
}
