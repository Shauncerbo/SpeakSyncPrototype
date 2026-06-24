import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/app.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/state/app_state.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.reset);
  }

  Future<AppState> openHome(WidgetTester tester) async {
    final state = AppState();
    await tester.pumpWidget(
      SpeakSyncApp(
        appState: state,
        splashDuration: Duration.zero,
        analysisDuration: Duration.zero,
        deviceCheckDuration: Duration.zero,
      ),
    );
    await tester.pump(Duration.zero);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> openSetup(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('start_practice')));
    await tester.pumpAndSettle();
  }

  Future<void> enterValidSetup(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('speech_title')),
      'Environmental Awareness Speech',
    );
    await tester.ensureVisible(find.byKey(const Key('setup_continue')));
    await tester.tap(find.byKey(const Key('setup_continue')));
    await tester.pumpAndSettle();
  }

  Future<void> openRehearsal(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('start_rehearsal')));
    await tester.tap(find.byKey(const Key('start_rehearsal')));
    await tester.pumpAndSettle();
  }

  testWidgets('1. Splash loads', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(SpeakSyncApp(appState: AppState()));

    expect(find.text('SpeakSync'), findsOneWidget);
    expect(
      find.text('Practice your speech. Improve your delivery.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('2. Get Started opens main app', (tester) async {
    await setPhoneSize(tester);
    final state = AppState();
    await tester.pumpWidget(
      SpeakSyncApp(appState: state, splashDuration: Duration.zero),
    );
    await tester.pump(Duration.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('get_started')));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Speaker!'), findsOneWidget);
  });

  testWidgets('3. Start Practice opens setup', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);

    expect(find.text('Practice Setup'), findsOneWidget);
    expect(find.byKey(const Key('speech_title')), findsOneWidget);
  });

  testWidgets('4. Empty title shows validation', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);

    await tester.ensureVisible(find.byKey(const Key('setup_continue')));
    await tester.tap(find.byKey(const Key('setup_continue')));
    await tester.pump();

    expect(find.text('Please enter a speech title.'), findsOneWidget);
  });

  testWidgets('5. Valid setup reaches Device Check', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester);

    expect(find.text('Device Check'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Microphone'), findsOneWidget);
  });

  testWidgets('6. Rehearsal loads', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester);
    await openRehearsal(tester);

    expect(find.text('Camera Preview Simulation'), findsOneWidget);
    expect(find.text('Fillers Detected'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('7. Simulate Kuan increases filler count', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester);
    await openRehearsal(tester);

    await tester.ensureVisible(find.byKey(const Key('demo_controls')));
    await tester.tap(find.byKey(const Key('demo_controls')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('simulate_kuan')));
    await tester.tap(find.byKey(const Key('simulate_kuan')));
    await tester.pump();

    expect(find.text('Kuan detected'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('filler_metric')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('8. End Session reaches report', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester);
    await openRehearsal(tester);

    await tester.ensureVisible(find.byKey(const Key('end_session')));
    await tester.tap(find.byKey(const Key('end_session')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_end_session')));
    await tester.pumpAndSettle();

    expect(find.text('Performance Report'), findsOneWidget);
    expect(find.text('Environmental Awareness Speech'), findsOneWidget);
  });

  testWidgets('9. Saving adds a progress entry', (tester) async {
    await setPhoneSize(tester);
    final state = AppState();
    final initialCount = state.sessions.length;
    state.setCurrentReport(
      PracticeSession(
        id: 'test-report',
        title: 'Test Speech',
        speechType: 'Prepared',
        languageMode: 'Mixed Language',
        dateTime: DateTime(2026, 6, 20),
        duration: const Duration(minutes: 2),
        overallScore: 90,
        paceScore: 92,
        fillerScore: 88,
        postureScore: 94,
        attentionScore: 86,
        fillerCounts: const {'Kuan': 1},
        coachingTips: const ['Keep using purposeful pauses.'],
        isPrototypeData: true,
      ),
    );
    await tester.pumpWidget(
      AppStateScope(
        notifier: state,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const ReportScreen(),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('save_progress')));
    await tester.tap(find.byKey(const Key('save_progress')));
    await tester.pump();

    expect(state.sessions.length, initialCount + 1);
    expect(state.sessions.first.title, 'Test Speech');
    expect(find.text('Session saved to Progress.'), findsOneWidget);
  });

  testWidgets('10. Settings switches update state', (tester) async {
    await setPhoneSize(tester);
    final state = await openHome(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(state.preferences.liveFeedback, isTrue);

    await tester.ensureVisible(find.byKey(const Key('settings_live_feedback')));
    await tester.tap(find.byKey(const Key('settings_live_feedback')));
    await tester.pump();

    expect(state.preferences.liveFeedback, isFalse);
  });
}
