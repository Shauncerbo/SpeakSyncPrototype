import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/data/dummy_data.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/screens/home_screen.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/screens/progress_screens.dart';
import 'package:speaksync_prototype/state/app_state.dart';
import 'package:speaksync_prototype/widgets/common_widgets.dart';

PracticeSession _legacyScoresWithMeasuredData({
  int? validPoseSeconds = 50,
  int? posturePercentage = 88,
  bool nullableScores = false,
  int? faceMilliseconds,
  int? facingSeconds,
  int? attention = 82,
}) => PracticeSession(
  id: 'session-measured',
  title: 'Measured rehearsal',
  speechType: 'Impromptu',
  languageMode: 'Mixed Language',
  dateTime: DateTime(2026, 10, 10),
  duration: const Duration(minutes: 1),
  overallScore: nullableScores ? null : 100,
  paceScore: nullableScores ? null : 94,
  fillerScore: nullableScores ? null : 100,
  postureScore: posturePercentage,
  goodPostureSeconds: 44,
  validPostureSeconds: validPoseSeconds,
  attentionScore: nullableScores && faceMilliseconds == null ? null : attention,
  cameraFacingSeconds: facingSeconds,
  validFaceAnalysisMilliseconds: faceMilliseconds,
  fillerCounts: const {'kuan': 1},
  coachingTips: const ['Strong eye contact and a perfect overall score!'],
  textTranscript: "Ku'an ${List.filled(139, 'word').join(' ')}",
  isPrototypeData: true,
);

void main() {
  test('Unavailable posture differs from measured zero percent', () {
    final unavailable = _legacyScoresWithMeasuredData(posturePercentage: null);
    final measuredZero = _legacyScoresWithMeasuredData(posturePercentage: 0);
    expect(unavailable.postureAnalysisUnavailable, isTrue);
    expect(unavailable.measuredPosturePercentage, isNull);
    expect(measuredZero.postureAnalysisUnavailable, isFalse);
    expect(measuredZero.measuredPosturePercentage, 0);
    expect(
      measuredZero.measuredCoachingTips.join(' '),
      contains('pose samples'),
    );
    expect(
      unavailable.measuredCoachingTips.join(' '),
      isNot(contains('pose samples')),
    );
  });

  test(
    'Legacy scores cannot become validated results or coaching evidence',
    () {
      final session = _legacyScoresWithMeasuredData();
      expect(session.validatedOverallScore, isNull);
      expect(session.measuredAttentionPercentage, isNull);
      expect(session.measuredPosturePercentage, 88);
      expect(session.speakingPace.wordsPerMinute, 140);
      expect(session.fillerAnalysis.counts, {'kuan': 1});
      expect(
        session.measuredCoachingTips.join(' '),
        isNot(contains('eye contact')),
      );
      expect(
        session.measuredCoachingTips.join(' '),
        isNot(contains('perfect')),
      );
      expect(session.measuredCoachingTips.join(' '), contains('transcript'));
    },
  );

  test(
    'Missing or insufficient pose coverage is not a measured percentage',
    () {
      for (final seconds in <int?>[null, 0, 2]) {
        final session = _legacyScoresWithMeasuredData(
          validPoseSeconds: seconds,
        );
        expect(session.measuredPosturePercentage, isNull);
      }
    },
  );

  test(
    'Prototype scores are excluded from the average without deleting history',
    () {
      final state = AppState();
      expect(state.sessions, hasLength(4));
      expect(state.averageScore, isNull);
      expect(state.sessions.every((session) => session.isDemoSession), isTrue);
    },
  );

  Future<void> render(
    WidgetTester tester,
    Widget screen,
    AppState state,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppStateScope(
        notifier: state,
        child: MaterialApp(home: Scaffold(body: screen)),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'Report hides scores and camera percentage, retains measured pose',
    (tester) async {
      final state = AppState()
        ..setCurrentReport(_legacyScoresWithMeasuredData());
      await render(tester, const ReportScreen(), state);
      expect(find.text('Not scored'), findsOneWidget);
      expect(find.text('out of 100'), findsNothing);
      expect(find.text('82%'), findsNothing);
      expect(find.text('88%'), findsOneWidget);
      expect(
        find.text('Unavailable — insufficient valid face analysis'),
        findsOneWidget,
      );
      expect(
        find.text('Strong eye contact and a perfect overall score!'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reopened legacy details cannot advertise dummy score strengths',
    (tester) async {
      await render(
        tester,
        SessionDetailsScreen(session: _legacyScoresWithMeasuredData()),
        AppState(),
      );
      expect(find.text('Not scored'), findsOneWidget);
      expect(find.textContaining('/100'), findsNothing);
      expect(find.text('82%'), findsNothing);
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('What you did well'), findsNothing);
      expect(
        find.text('Strong eye contact and a perfect overall score!'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home and progress do not display prototype scores or rankings', (
    tester,
  ) async {
    final state = AppState();
    await render(tester, HomeScreen(onViewProgress: () {}), state);
    expect(find.text('Not scored'), findsOneWidget);
    expect(find.text('82/100'), findsNothing);
    expect(find.text('+6 pts'), findsNothing);
    await render(tester, const ProgressScreen(), state);
    expect(find.text('Not scored'), findsOneWidget);
    expect(find.text('Rankings unavailable'), findsOneWidget);
    expect(find.text('BEST REHEARSAL'), findsNothing);
    expect(find.text('#1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nullable report retains real WPM, fillers, and zero posture', (
    tester,
  ) async {
    final session = _legacyScoresWithMeasuredData(
      nullableScores: true,
      posturePercentage: 0,
    );
    final state = AppState()..setCurrentReport(session);
    await render(tester, const ReportScreen(), state);
    expect(find.text('Not scored'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(session.speakingPace.wordsPerMinute, 140);
    expect(session.fillerAnalysis.counts, {'kuan': 1});
    expect(find.text('82%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unavailable posture is not displayed as zero percent', (
    tester,
  ) async {
    final state = AppState()
      ..setCurrentReport(
        _legacyScoresWithMeasuredData(
          nullableScores: true,
          posturePercentage: null,
        ),
      );
    await render(tester, const ReportScreen(), state);
    expect(find.text('0%'), findsNothing);
    expect(find.textContaining('Unavailable'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Score chart does not plot legacy prototype values', (
    tester,
  ) async {
    await render(
      tester,
      ProgressChart(sessions: initialSessions()),
      AppState(),
    );
    expect(find.textContaining('Score trend unavailable'), findsOneWidget);
    expect(find.text('Overall score'), findsNothing);
  });

  testWidgets('Genuine head-facing percentage appears in report and history', (
    tester,
  ) async {
    final session = _legacyScoresWithMeasuredData(
      nullableScores: true,
      faceMilliseconds: 5000,
      facingSeconds: 3,
      attention: 60,
    );
    final state = AppState()..setCurrentReport(session);
    await render(tester, const ReportScreen(), state);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Not scored'), findsOneWidget);
    expect(
      find.text('Percentage of valid face-analysis time, not eye contact'),
      findsOneWidget,
    );
    await render(tester, SessionDetailsScreen(session: session), state);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Not scored'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
