import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/screens/progress_screens.dart';
import 'package:speaksync_prototype/services/topic_attempt_tracking.dart';
import 'package:speaksync_prototype/state/app_state.dart';

String _transcript(int wordCount, {int fillers = 0}) => [
  ...List<String>.filled(fillers, 'um'),
  ...List<String>.filled(wordCount - fillers, 'speech'),
].join(' ');

PracticeSession _session({
  required String id,
  required String title,
  required String speechType,
  required DateTime date,
  int words = 130,
  int fillers = 0,
  int? posture,
  int? facing,
  bool monitorPace = true,
  bool monitorFillers = true,
  bool monitorBody = true,
  bool monitorFacing = true,
  String? script,
  String? documentName,
}) => PracticeSession(
  id: id,
  title: title,
  speechType: speechType,
  languageMode: 'Mixed Language',
  dateTime: date,
  duration: const Duration(minutes: 1),
  overallScore: null,
  paceScore: null,
  fillerScore: null,
  postureScore: posture,
  goodPostureSeconds: posture == null ? null : (posture * .6).round(),
  validPostureSeconds: posture == null ? null : 60,
  attentionScore: facing,
  cameraFacingSeconds: facing == null ? null : (facing * .6).round(),
  validFaceAnalysisMilliseconds: facing == null ? null : 60000,
  fillerCounts: const {},
  coachingTips: const [],
  textTranscript: _transcript(words, fillers: fillers),
  referenceScript: script,
  referenceDocumentName: documentName,
  monitorPace: monitorPace,
  monitorFillers: monitorFillers,
  monitorBodyLanguage: monitorBody,
  monitorCameraAttention: monitorFacing,
  isPrototypeData: false,
);

class _ScoredSession extends PracticeSession {
  _ScoredSession({
    required super.id,
    required DateTime date,
    required this.score,
    bool prototype = false,
  }) : super(
         title: 'Future Scored Topic',
         speechType: 'Impromptu',
         languageMode: 'English',
         dateTime: date,
         duration: const Duration(minutes: 1),
         overallScore: score,
         paceScore: null,
         fillerScore: null,
         postureScore: null,
         attentionScore: null,
         fillerCounts: const {},
         coachingTips: const [],
         textTranscript: 'A complete measured rehearsal transcript',
         isPrototypeData: prototype,
       );

  final int score;

  @override
  int? get validatedOverallScore => score;
}

Widget _harness(Widget child, {AppState? state}) => AppStateScope(
  notifier: state ?? AppState(),
  child: MaterialApp(home: child),
);

void main() {
  group('topic grouping', () {
    test(
      'same normalized topic and speech type become chronological attempts',
      () {
        final third = _session(
          id: 'third',
          title: 'The Importance of Education!',
          speechType: 'Prepared',
          date: DateTime(2026, 3, 3),
        );
        final first = _session(
          id: 'first',
          title: ' The Importance of Education ',
          speechType: 'Prepared',
          date: DateTime(2026, 3, 1),
        );
        final second = _session(
          id: 'second',
          title: 'The Importance-of Education',
          speechType: 'Prepared',
          date: DateTime(2026, 3, 2),
        );

        final group = TopicAttemptTracking.groupSessions([
          third,
          first,
          second,
        ]).single;

        expect(group.attempts.map((attempt) => attempt.id), [
          'first',
          'second',
          'third',
        ]);
        expect(group.attemptNumberFor('first'), 1);
        expect(group.attemptNumberFor('third'), 3);
      },
    );

    test('different topics and speech types remain separate', () {
      final groups = TopicAttemptTracking.groupSessions([
        _session(
          id: 'prepared',
          title: 'Education',
          speechType: 'Prepared',
          date: DateTime(2026, 1, 1),
        ),
        _session(
          id: 'persuasive',
          title: 'Education',
          speechType: 'Persuasive',
          date: DateTime(2026, 1, 2),
        ),
        _session(
          id: 'other',
          title: 'Environment',
          speechType: 'Prepared',
          date: DateTime(2026, 1, 3),
        ),
      ]);

      expect(groups, hasLength(3));
      expect(groups.map((group) => group.key).toSet(), hasLength(3));
    });

    test('legacy numeric scores are not ranked or marked best', () {
      final legacy = PracticeSession(
        id: 'legacy',
        title: 'Legacy Topic',
        speechType: 'Impromptu',
        languageMode: 'English',
        dateTime: DateTime(2025),
        duration: const Duration(minutes: 1),
        overallScore: 99,
        paceScore: 99,
        fillerScore: 99,
        postureScore: null,
        attentionScore: null,
        fillerCounts: const {},
        coachingTips: const [],
        textTranscript: 'Legacy transcript',
        isPrototypeData: true,
      );
      final group = TopicAttemptTracking.groupSessions([legacy]).single;

      expect(legacy.validatedOverallScore, isNull);
      expect(group.rankingAvailable, isFalse);
      expect(group.bestAttempt, isNull);
    });

    test('future validated scores rank separately from attempt numbers', () {
      final first = _ScoredSession(
        id: 'first',
        date: DateTime(2026, 1, 1),
        score: 70,
      );
      final second = _ScoredSession(
        id: 'second',
        date: DateTime(2026, 1, 2),
        score: 90,
      );
      final prototype = _ScoredSession(
        id: 'prototype',
        date: DateTime(2026, 1, 3),
        score: 100,
        prototype: true,
      );
      final group = TopicAttemptTracking.groupSessions([
        first,
        second,
        prototype,
      ]).single;

      expect(group.attemptNumberFor('second'), 2);
      expect(group.performanceRankFor('second'), 1);
      expect(group.bestAttempt?.id, 'second');
      expect(group.performanceRankFor('prototype'), isNull);
    });
  });

  group('measurement comparisons', () {
    test('compares first and latest actual measurements', () {
      final first = _session(
        id: 'first',
        title: 'Education',
        speechType: 'Impromptu',
        date: DateTime(2026, 1, 1),
        words: 100,
        fillers: 5,
        posture: 60,
        facing: 70,
      );
      final latest = _session(
        id: 'latest',
        title: 'Education',
        speechType: 'Impromptu',
        date: DateTime(2026, 1, 2),
        words: 130,
        fillers: 1,
        posture: 80,
        facing: 85,
      );
      final comparisons = TopicAttemptTracking.groupSessions([
        latest,
        first,
      ]).single.improvementComparisons;

      expect(comparisons.map((item) => item.label), [
        'Speaking pace',
        'Filler frequency',
        'Acceptable posture time',
        'Estimated camera-facing time',
      ]);
      expect(
        comparisons.every((item) => item.trend == TopicMetricTrend.improved),
        isTrue,
      );
    });

    test('disabled and unavailable measurements are not treated as zero', () {
      final group = TopicAttemptTracking.groupSessions([
        _session(
          id: 'first',
          title: 'Unavailable',
          speechType: 'Impromptu',
          date: DateTime(2026, 1, 1),
          monitorPace: false,
          monitorFillers: false,
          monitorBody: false,
          monitorFacing: false,
        ),
        _session(
          id: 'latest',
          title: 'Unavailable',
          speechType: 'Impromptu',
          date: DateTime(2026, 1, 2),
          monitorPace: false,
          monitorFillers: false,
          monitorBody: false,
          monitorFacing: false,
        ),
      ]).single;

      expect(group.improvementComparisons, isEmpty);
    });
  });

  testWidgets('topic screen shows chronological attempts and safe ranking', (
    tester,
  ) async {
    final group = TopicAttemptTracking.groupSessions([
      _session(
        id: 'first',
        title: 'The Importance of Education',
        speechType: 'Impromptu',
        date: DateTime(2026, 1, 1),
      ),
      _session(
        id: 'second',
        title: 'The Importance of Education',
        speechType: 'Impromptu',
        date: DateTime(2026, 1, 2),
      ),
      _session(
        id: 'third',
        title: 'The Importance of Education',
        speechType: 'Impromptu',
        date: DateTime(2026, 1, 3),
      ),
    ]).single;
    await tester.pumpWidget(_harness(TopicAttemptsScreen(group: group)));

    expect(find.text('Topic: The Importance of Education'), findsOneWidget);
    expect(
      find.text('Ranking unavailable until valid scores are available.'),
      findsOneWidget,
    );
    expect(find.text('Best Attempt'), findsNothing);
    expect(find.text('Attempt 1'), findsOneWidget);
    expect(find.text('Attempt 2'), findsOneWidget);
    expect(find.text('Attempt 3'), findsOneWidget);
  });

  testWidgets('each attempt opens its detailed saved report', (tester) async {
    final session = _session(
      id: 'details',
      title: 'Community Service',
      speechType: 'Impromptu',
      date: DateTime(2026, 1, 1),
    );
    final group = TopicAttemptTracking.groupSessions([session]).single;
    await tester.pumpWidget(_harness(TopicAttemptsScreen(group: group)));
    await tester.ensureVisible(find.byKey(const Key('topic_attempt_1')));
    await tester.tap(find.byKey(const Key('topic_attempt_1')));
    await tester.pumpAndSettle();

    expect(find.text('Session Details'), findsOneWidget);
    expect(find.text('Community Service'), findsOneWidget);
  });

  testWidgets(
    'practice topic again prefills type, topic, and prepared script',
    (tester) async {
      final prepared = _session(
        id: 'prepared',
        title: 'Education for Everyone',
        speechType: 'Prepared',
        date: DateTime(2026, 1, 1),
        script: 'Education creates opportunities for every learner.',
        documentName: 'education.txt',
      );
      final group = TopicAttemptTracking.groupSessions([prepared]).single;
      await tester.pumpWidget(_harness(TopicAttemptsScreen(group: group)));
      await tester.ensureVisible(find.byKey(const Key('practice_topic_again')));
      await tester.tap(find.byKey(const Key('practice_topic_again')));
      await tester.pumpAndSettle();

      final title = tester.widget<TextFormField>(
        find.byKey(const Key('speech_title')),
      );
      final script = tester.widget<TextFormField>(
        find.byKey(const Key('speech_content')),
      );
      expect(title.controller?.text, 'Education for Everyone');
      expect(script.controller?.text, contains('creates opportunities'));
      expect(find.text('Prepared'), findsOneWidget);
      expect(find.text('education.txt'), findsOneWidget);
    },
  );

  testWidgets('persuasive retry also preserves its reference script', (
    tester,
  ) async {
    final persuasive = _session(
      id: 'persuasive',
      title: 'Protecting Local Rivers',
      speechType: 'Persuasive',
      date: DateTime(2026, 1, 1),
      script: 'Our community should protect local rivers together.',
    );
    await tester.pumpWidget(
      _harness(PracticeSetupScreen(initialSession: persuasive)),
    );

    final script = tester.widget<TextFormField>(
      find.byKey(const Key('speech_content')),
    );
    expect(find.text('Persuasive'), findsOneWidget);
    expect(script.controller?.text, contains('protect local rivers'));
  });

  testWidgets('impromptu retry keeps topic but does not require a script', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        PracticeSetupScreen(
          initialSession: _session(
            id: 'impromptu',
            title: 'My Community',
            speechType: 'Impromptu',
            date: DateTime(2026, 1, 1),
          ),
        ),
      ),
    );

    final title = tester.widget<TextFormField>(
      find.byKey(const Key('speech_title')),
    );
    expect(title.controller?.text, 'My Community');
    expect(find.text('Impromptu'), findsOneWidget);
    expect(find.byKey(const Key('speech_content')), findsNothing);
    expect(find.text('No script needed'), findsOneWidget);
  });

  testWidgets(
    'report retry saves the completed attempt before prefilling setup',
    (tester) async {
      final state = AppState(useDemoData: false);
      await state.activateAuthenticatedUser(
        userId: 'firebase-report-retry',
        email: 'retry@example.com',
        displayName: 'Retry Student',
      );
      final report = _session(
        id: 'completed-attempt',
        title: 'Education for Everyone',
        speechType: 'Prepared',
        date: DateTime(2026, 1, 1),
        script: 'Education creates opportunities for every learner.',
      );
      state.setCurrentReport(report);
      await tester.pumpWidget(_harness(const ReportScreen(), state: state));
      await tester.ensureVisible(
        find.byKey(const Key('practice_topic_again_report')),
      );
      await tester.tap(find.byKey(const Key('practice_topic_again_report')));
      await tester.pumpAndSettle();

      expect(state.sessions.map((session) => session.id), [
        'completed-attempt',
      ]);
      expect(find.byType(PracticeSetupScreen), findsOneWidget);
      final title = tester.widget<TextFormField>(
        find.byKey(const Key('speech_title')),
      );
      expect(title.controller?.text, 'Education for Everyone');
    },
  );

  testWidgets('topic attempts remain usable on a small Android layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final group = TopicAttemptTracking.groupSessions([
      _session(
        id: 'small-1',
        title: 'A Long Community Education Topic',
        speechType: 'Impromptu',
        date: DateTime(2026, 1, 1),
      ),
      _session(
        id: 'small-2',
        title: 'A Long Community Education Topic',
        speechType: 'Impromptu',
        date: DateTime(2026, 1, 2),
      ),
    ]).single;
    await tester.pumpWidget(_harness(TopicAttemptsScreen(group: group)));
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
