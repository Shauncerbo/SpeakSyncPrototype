import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/state/app_state.dart';
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
}
