import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/models/rehearsal_session.dart';
import 'package:speaksync_prototype/state/app_state.dart';
import 'package:speaksync_prototype/services/topic_attempt_tracking.dart';
import 'package:speaksync_prototype/storage/hive_box_names.dart';
import 'package:speaksync_prototype/storage/hive_repository.dart';

PracticeSession _session(String id, String title) => PracticeSession(
  id: id,
  title: title,
  speechType: 'Impromptu',
  languageMode: 'Mixed Language',
  dateTime: DateTime(2026, 11, 4),
  duration: const Duration(minutes: 1),
  overallScore: null,
  paceScore: null,
  fillerScore: null,
  postureScore: null,
  attentionScore: null,
  fillerCounts: const {},
  coachingTips: const [],
  textTranscript: 'This is a private student rehearsal transcript.',
  isPrototypeData: false,
);

void main() {
  late Directory storageDirectory;

  setUp(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'speaksync-auth-storage-',
    );
  });

  tearDown(() async {
    await Hive.close();
    if (await storageDirectory.exists()) {
      await storageDirectory.delete(recursive: true);
    }
  });

  test(
    'Firebase UIDs isolate Hive sessions and preserve demo records',
    () async {
      final repository = HiveRepository();
      await repository.initializeStorage(storagePath: storageDirectory.path);
      final state = AppState(repository: repository, useDemoData: false);
      await state.initialize();

      expect(state.activeUserId, isNull);
      expect(state.sessions, isEmpty);
      expect(repository.getPracticeSessions(AppUserIds.demo), hasLength(4));

      await state.activateAuthenticatedUser(
        userId: 'firebase-user-a',
        email: 'a@example.com',
        firstName: 'Student',
        lastName: 'A',
      );
      state.setCurrentReport(_session('user-a-session', 'Student A Speech'));
      expect(await state.saveCurrentReport(), isTrue);
      expect(state.sessions.map((item) => item.id), ['user-a-session']);

      await state.activateAuthenticatedUser(
        userId: 'firebase-user-b',
        email: 'b@example.com',
        firstName: 'Student',
        lastName: 'B',
      );
      expect(state.sessions, isEmpty);
      state.setCurrentReport(_session('user-b-session', 'Student B Speech'));
      expect(await state.saveCurrentReport(), isTrue);
      expect(state.sessions.map((item) => item.id), ['user-b-session']);

      await state.activateAuthenticatedUser(
        userId: 'firebase-user-a',
        email: 'a@example.com',
        displayName: 'Student A',
      );
      expect(state.sessions.map((item) => item.id), ['user-a-session']);
      expect(
        repository
            .getPracticeSessions('firebase-user-b')
            .map((item) => item.id),
        ['user-b-session'],
      );
      expect(repository.getPracticeSessions(AppUserIds.demo), hasLength(4));
      expect(state.sessions.single.isPrototypeData, isFalse);
      expect(
        repository
            .getPracticeSessions(AppUserIds.demo)
            .every((session) => session.isPrototypeData),
        isTrue,
      );

      state.clearAuthenticatedUser();
      expect(state.sessions, isEmpty);
      expect(state.activeUserId, isNull);
    },
  );

  test('student accounts cannot restore or clear demo data', () async {
    final repository = HiveRepository();
    await repository.initializeStorage(storagePath: storageDirectory.path);
    final state = AppState(repository: repository, useDemoData: false);
    await state.initialize();
    await state.activateAuthenticatedUser(
      userId: 'firebase-user',
      email: 'student@example.com',
      displayName: 'Student User',
    );

    await expectLater(
      state.restoreDemoData(),
      throwsA(isA<StorageException>()),
    );
    await expectLater(
      state.clearPrototypeData(),
      throwsA(isA<StorageException>()),
    );
    expect(repository.getPracticeSessions(AppUserIds.demo), hasLength(4));
    expect(state.sessions, isEmpty);
  });

  test('tutorial completion is persisted separately for each UID', () async {
    var repository = HiveRepository();
    await repository.initializeStorage(storagePath: storageDirectory.path);
    var state = AppState(repository: repository, useDemoData: false);
    await state.initialize();

    await state.activateAuthenticatedUser(
      userId: 'firebase-tutorial-a',
      email: 'tutorial-a@example.com',
      displayName: 'Tutorial Student A',
    );
    expect(state.shouldShowFirstLoginTutorial, isTrue);
    await state.markFirstLoginTutorialCompleted();
    expect(state.shouldShowFirstLoginTutorial, isFalse);
    expect(repository.hasCompletedTutorial('firebase-tutorial-a'), isTrue);

    await state.activateAuthenticatedUser(
      userId: 'firebase-tutorial-b',
      email: 'tutorial-b@example.com',
      displayName: 'Tutorial Student B',
    );
    expect(state.shouldShowFirstLoginTutorial, isTrue);
    expect(repository.hasCompletedTutorial('firebase-tutorial-b'), isFalse);

    await Hive.close();
    repository = HiveRepository();
    await repository.initializeStorage(storagePath: storageDirectory.path);
    state = AppState(repository: repository, useDemoData: false);
    await state.initialize();
    await state.activateAuthenticatedUser(
      userId: 'firebase-tutorial-a',
      email: 'tutorial-a@example.com',
      displayName: 'Tutorial Student A',
    );
    expect(state.shouldShowFirstLoginTutorial, isFalse);
  });

  test(
    'incomplete rehearsals without reports are not listed as attempts',
    () async {
      final repository = HiveRepository();
      await repository.initializeStorage(storagePath: storageDirectory.path);
      final state = AppState(repository: repository, useDemoData: false);
      await state.initialize();
      await state.activateAuthenticatedUser(
        userId: 'firebase-incomplete',
        email: 'incomplete@example.com',
        displayName: 'Incomplete Student',
      );
      await repository.saveRehearsalSession(
        RehearsalSession(
          sessionId: 'unfinished-session',
          userId: 'firebase-incomplete',
          speechTitle: 'Unfinished Topic',
          speechType: 'Impromptu',
          languageMode: 'English',
          targetDurationSeconds: 60,
          durationSeconds: 10,
          sessionDate: DateTime(2026, 11, 8),
          liveAlertsEnabled: true,
          bodyLanguageEnabled: true,
          fillerWordEnabled: true,
          speakingPaceEnabled: true,
          cameraAttentionEnabled: true,
        ),
      );

      final completed = repository.getPracticeSessions('firebase-incomplete');
      expect(completed, isEmpty);
      expect(TopicAttemptTracking.groupSessions(completed), isEmpty);
    },
  );

  test(
    'topic attempts persist after restart and remain isolated by UID',
    () async {
      var repository = HiveRepository();
      await repository.initializeStorage(storagePath: storageDirectory.path);
      var state = AppState(repository: repository, useDemoData: false);
      await state.initialize();
      await state.activateAuthenticatedUser(
        userId: 'firebase-topic-a',
        email: 'topic-a@example.com',
        displayName: 'Topic Student A',
      );
      state.setCurrentReport(_session('topic-a-1', 'Education for Everyone'));
      expect(await state.saveCurrentReport(), isTrue);
      state.setCurrentReport(_session('topic-a-2', 'Education for Everyone!'));
      expect(await state.saveCurrentReport(), isTrue);

      await state.activateAuthenticatedUser(
        userId: 'firebase-topic-b',
        email: 'topic-b@example.com',
        displayName: 'Topic Student B',
      );
      state.setCurrentReport(_session('topic-b-1', 'Education for Everyone'));
      expect(await state.saveCurrentReport(), isTrue);

      await Hive.close();
      repository = HiveRepository();
      await repository.initializeStorage(storagePath: storageDirectory.path);
      state = AppState(repository: repository, useDemoData: false);
      await state.initialize();

      await state.activateAuthenticatedUser(
        userId: 'firebase-topic-a',
        email: 'topic-a@example.com',
        displayName: 'Topic Student A',
      );
      final userAGroups = TopicAttemptTracking.groupSessions(state.sessions);
      expect(userAGroups, hasLength(1));
      expect(userAGroups.single.attempts, hasLength(2));
      expect(userAGroups.single.attempts.map((attempt) => attempt.id).toSet(), {
        'topic-a-1',
        'topic-a-2',
      });

      await state.activateAuthenticatedUser(
        userId: 'firebase-topic-b',
        email: 'topic-b@example.com',
        displayName: 'Topic Student B',
      );
      final userBGroups = TopicAttemptTracking.groupSessions(state.sessions);
      expect(userBGroups, hasLength(1));
      expect(userBGroups.single.attempts.single.id, 'topic-b-1');
    },
  );
}
