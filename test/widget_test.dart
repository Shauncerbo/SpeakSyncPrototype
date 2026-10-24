import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/app.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/services/internet_connectivity_service.dart';
import 'package:speaksync_prototype/state/app_state.dart';
import 'package:speaksync_prototype/widgets/pose_landmark_overlay.dart';

class _FakeInternetConnectivity implements InternetConnectivity {
  _FakeInternetConnectivity(this._connected);

  bool _connected;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> check() async => _connected;

  @override
  Stream<bool> get statusChanges => _controller.stream;

  void setConnected(bool connected) {
    _connected = connected;
    _controller.add(connected);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.reset);
  }

  Future<AppState> openHome(
    WidgetTester tester, {
    InternetConnectivity? internetConnectivity,
  }) async {
    final state = AppState();
    final connectivity =
        internetConnectivity ?? _FakeInternetConnectivity(true);
    if (internetConnectivity == null) {
      addTearDown((connectivity as _FakeInternetConnectivity).dispose);
    }
    await tester.pumpWidget(
      SpeakSyncApp(
        appState: state,
        splashDuration: Duration.zero,
        analysisDuration: Duration.zero,
        deviceCheckDuration: Duration.zero,
        internetConnectivity: connectivity,
      ),
    );
    await tester.pump(Duration.zero);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> openSetup(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('start_practice')));
    await tester.pumpAndSettle();
  }

  Future<void> enterValidSetup(
    WidgetTester tester, {
    String duration = '3 minutes',
    bool openPreview = true,
  }) async {
    await tester.enterText(
      find.byKey(const Key('speech_title')),
      'Environmental Awareness Speech',
    );
    await tester.tap(find.byKey(const Key('speech_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Impromptu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mixed Language').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('duration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(duration).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('setup_continue')));
    await tester.tap(find.byKey(const Key('setup_continue')));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceCheckScreen), findsOneWidget);
    expect(find.byType(RehearsalScreen), findsNothing);
    expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
    if (openPreview) {
      await tester.ensureVisible(find.byKey(const Key('start_rehearsal')));
      await tester.tap(find.byKey(const Key('start_rehearsal')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> openRehearsal(WidgetTester tester) async {
    final startButton = find.byKey(const Key('ready_rehearsal'));
    await tester.ensureVisible(startButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(startButton).onPressed, isNotNull);
    await tester.tap(startButton);
    await tester.pump();
    for (var second = 0; second < 3; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    expect(find.text('Rehearsal'), findsOneWidget);
  }

  testWidgets('1. Splash loads', (tester) async {
    await setPhoneSize(tester);
    final connectivity = _FakeInternetConnectivity(true);
    addTearDown(connectivity.dispose);
    await tester.pumpWidget(
      SpeakSyncApp(appState: AppState(), internetConnectivity: connectivity),
    );

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
    final connectivity = _FakeInternetConnectivity(true);
    addTearDown(connectivity.dispose);
    await tester.pumpWidget(
      SpeakSyncApp(
        appState: state,
        splashDuration: Duration.zero,
        internetConnectivity: connectivity,
      ),
    );
    await tester.pump(Duration.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('get_started')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Speaker!'), findsOneWidget);
  });

  testWidgets('3. Start Practice opens setup', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    expect(find.byKey(const Key('quick_start_practice')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quick_start_practice')));
    await tester.pumpAndSettle();

    expect(find.text('Practice Setup'), findsOneWidget);
    expect(find.byKey(const Key('speech_title')), findsOneWidget);
    expect(find.byKey(const Key('speech_type')), findsOneWidget);
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

  testWidgets('5. Valid setup opens Device Check before camera readiness', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester);

    expect(find.text('Camera Preview'), findsOneWidget);
    expect(find.byKey(const Key('rehearsal_readiness')), findsOneWidget);
    expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
    expect(find.byKey(const Key('toggle_microphone')), findsNothing);
    expect(find.byKey(const Key('end_session')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final speechType in ['Prepared', 'Persuasive']) {
    testWidgets('$speechType accepts a manually typed reference script', (
      tester,
    ) async {
      await setPhoneSize(tester);
      final state = await openHome(tester);
      await openSetup(tester);
      await tester.enterText(
        find.byKey(const Key('speech_title')),
        '$speechType Speech',
      );
      await tester.tap(find.byKey(const Key('speech_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(speechType).last);
      await tester.pumpAndSettle();
      final scriptField = find.byKey(const Key('speech_content'));
      await tester.ensureVisible(scriptField);
      await tester.enterText(
        scriptField,
        'Good morning. This is my manually entered reference script.',
      );
      final languageField = find.byKey(const Key('language_mode'));
      await tester.ensureVisible(languageField);
      await tester.pumpAndSettle();
      await tester.tap(languageField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mixed Language').last);
      await tester.pumpAndSettle();
      final durationField = find.byKey(const Key('duration'));
      await tester.ensureVisible(durationField);
      await tester.pumpAndSettle();
      await tester.tap(durationField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 minute').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('setup_continue')));
      await tester.tap(find.byKey(const Key('setup_continue')));
      await tester.pumpAndSettle();

      expect(find.byType(DeviceCheckScreen), findsOneWidget);
      expect(state.currentSetup?.speechType, speechType);
      expect(
        state.currentSetup?.speechContent,
        'Good morning. This is my manually entered reference script.',
      );
      expect(state.currentSetup?.referenceDocumentName, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('Preview and countdown time are excluded from the saved report', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final state = await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester, duration: '1 minute');
    await tester.pump(const Duration(minutes: 2));
    expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
    expect(find.byKey(const Key('prototype_alert_controls')), findsNothing);
    expect(find.byKey(const Key('filler_metric')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    for (final number in ['3', '2', '1']) {
      expect(
        tester.widget<Text>(find.byKey(const Key('readiness_countdown'))).data,
        number,
      );
      expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    expect(find.text('01:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.ensureVisible(find.byKey(const Key('end_session')));
    await tester.tap(find.byKey(const Key('end_session')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_end_session')));
    await tester.pumpAndSettle();
    expect(state.currentReport?.duration, const Duration(seconds: 10));
  });

  testWidgets('Countdown cancellation returns to preview and can start again', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final state = await openHome(tester);
    final count = state.sessions.length;
    await openSetup(tester);
    await enterValidSetup(tester);
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('cancel_countdown')));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const Key('readiness_countdown')), findsNothing);
    expect(find.byKey(const Key('rehearsal_readiness')), findsOneWidget);
    expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
    expect(state.sessions.length, count);
    expect(state.currentReport, isNull);
    await openRehearsal(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final duringCountdown in [false, true]) {
    testWidgets(
      'Back before rehearsal saves nothing (countdown: $duringCountdown)',
      (tester) async {
        await setPhoneSize(tester);
        final state = await openHome(tester);
        final count = state.sessions.length;
        await openSetup(tester);
        await enterValidSetup(tester);
        if (duringCountdown) {
          await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
          await tester.tap(find.byKey(const Key('ready_rehearsal')));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byKey(const Key('leave_readiness')));
        }
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        expect(find.byType(DeviceCheckScreen), findsOneWidget);
        expect(find.byType(RehearsalScreen), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Practice Setup'), findsOneWidget);
        expect(find.text('Performance Report'), findsNothing);
        expect(state.currentReport, isNull);
        expect(state.sessions.length, count);
      },
    );
  }

  testWidgets(
    'Backgrounding cancels the countdown without starting rehearsal',
    (tester) async {
      await setPhoneSize(tester);
      await openHome(tester);
      await openSetup(tester);
      await enterValidSetup(tester);
      await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
      await tester.tap(find.byKey(const Key('ready_rehearsal')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const Key('readiness_countdown')), findsNothing);
      expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('6. Rehearsal loads', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester);
    await openRehearsal(tester);

    expect(find.byKey(const Key('toggle_microphone')), findsOneWidget);
    expect(find.byKey(const Key('toggle_camera')), findsOneWidget);
    expect(find.text('Fillers Detected'), findsOneWidget);
    expect(find.byKey(const Key('show_pose_landmarks_toggle')), findsNothing);
    expect(find.byType(PoseLandmarkOverlay), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('7. Prototype demo controls are removed', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester);
    await openRehearsal(tester);

    expect(find.byKey(const Key('demo_controls')), findsNothing);
    expect(find.byKey(const Key('prototype_alert_controls')), findsNothing);
    expect(find.byKey(const Key('test_filler_alert')), findsNothing);
    expect(find.byKey(const Key('test_fast_speech_alert')), findsNothing);
    expect(find.text('82%'), findsNothing);
    expect(find.text('Prototype Demo Controls'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Camera-facing attention toggle controls rehearsal monitoring', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final state = await openHome(tester);
    await openSetup(tester);
    final cameraSwitch = find.byKey(const Key('camera_attention_monitoring'));
    await tester.ensureVisible(cameraSwitch);
    expect(tester.widget<SwitchListTile>(cameraSwitch).value, isTrue);
    expect(tester.widget<SwitchListTile>(cameraSwitch).onChanged, isNotNull);
    expect(
      find.text('Estimated head direction, not eye contact (Android)'),
      findsOneWidget,
    );
    await tester.tap(cameraSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(cameraSwitch).value, isFalse);
    await tester.ensureVisible(find.byKey(const Key('speech_title')));
    await tester.pumpAndSettle();
    await enterValidSetup(tester);
    expect(state.currentSetup!.monitorCameraAttention, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Privacy distinguishes cloud speech from local visual analysis', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View Privacy Details'));
    await tester.tap(find.text('View Privacy Details'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Groq Cloud API for OpenAI Whisper'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'MediaPipe Pose and Face analyze camera frames locally',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('stored locally using Hive'), findsOneWidget);
    expect(find.textContaining('Crashes or cleanup errors'), findsOneWidget);
    expect(
      find.textContaining('Immediate deletion by Groq has not been verified'),
      findsOneWidget,
    );
    expect(find.text('No cloud upload or automatic sharing.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('8. End Session reaches report', (tester) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester);
    await openRehearsal(tester);

    await tester.ensureVisible(find.byKey(const Key('end_session')));
    await tester.tap(find.byKey(const Key('end_session')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('confirm_end_session')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Performance Report'), findsOneWidget);
    expect(find.text('Environmental Awareness Speech'), findsOneWidget);
  });

  testWidgets('9. Fixed duration warns and ends automatically', (tester) async {
    await setPhoneSize(tester);
    final state = await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester, duration: '1 minute');
    await openRehearsal(tester);

    expect(find.text('01:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('00:30'), findsOneWidget);
    expect(
      find.text('30 seconds remaining — your rehearsal is almost done'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Performance Report'), findsOneWidget);
    expect(state.currentReport?.duration, const Duration(minutes: 1));
  });

  testWidgets('Restart confirmation resets timer and allows another restart', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final state = await openHome(tester);
    final savedCount = state.sessions.length;
    await openSetup(tester);
    await enterValidSetup(tester, duration: '1 minute');
    await openRehearsal(tester);

    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('00:30'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('restart_session')));
      await tester.tap(find.byKey(const Key('restart_session')));
      await tester.pump(const Duration(milliseconds: 500));
      // The old attempt must not end while confirmation is open.
      await tester.pump(const Duration(seconds: 40));
      expect(find.text('Performance Report'), findsNothing);
      await tester.tap(find.byKey(const Key('confirm_restart_session')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('01:00'), findsOneWidget);
      expect(state.sessions.length, savedCount);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('restart_session')))
            .onPressed,
        isNotNull,
      );
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:59'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Cancel restart keeps existing rehearsal progress', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await openHome(tester);
    await openSetup(tester);
    await enterValidSetup(tester, duration: '1 minute');
    await openRehearsal(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('00:50'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('restart_session')));
    await tester.tap(find.byKey(const Key('restart_session')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('00:50'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:49'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('10. Saving adds a progress entry', (tester) async {
    await setPhoneSize(tester);
    final state = AppState();
    await state.updatePreferences(
      state.preferences.copyWith(liveFeedback: false),
    );
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

  testWidgets('11. Settings switches update state', (tester) async {
    await setPhoneSize(tester);
    final state = await openHome(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(state.preferences.liveFeedback, isTrue);
    expect(find.text('Practice preferences'), findsNothing);
    expect(find.text('Default language'), findsNothing);
    expect(find.text('Default duration'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('settings_live_feedback')));
    await tester.tap(find.byKey(const Key('settings_live_feedback')));
    await tester.pump();

    expect(state.preferences.liveFeedback, isFalse);
  });

  testWidgets('Transcription errors remain visible with Live Feedback OFF', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final state = AppState();
    await state.updatePreferences(
      state.preferences.copyWith(liveFeedback: false),
    );
    await tester.pumpWidget(
      AppStateScope(
        notifier: state,
        child: AppTimingScope(
          splashDuration: Duration.zero,
          deviceCheckDuration: Duration.zero,
          internetConnectivity: _FakeInternetConnectivity(true),
          analysisDuration: const Duration(days: 1),
          child: const MaterialApp(
            home: AnalyzingScreen(
              transcriptionErrorMessage:
                  'Groq could not transcribe this recording.',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Transcript unavailable'), findsOneWidget);
    expect(
      find.text('Groq could not transcribe this recording.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'Connectivity notices remain global during rehearsal with Live Feedback OFF',
    (tester) async {
      await setPhoneSize(tester);
      final connectivity = _FakeInternetConnectivity(true);
      addTearDown(connectivity.dispose);
      final state = await openHome(tester, internetConnectivity: connectivity);
      await state.updatePreferences(
        state.preferences.copyWith(liveFeedback: false),
      );
      await openSetup(tester);
      await enterValidSetup(tester);
      await openRehearsal(tester);
      expect(state.currentSetup!.enableLiveFeedback, isFalse);
      connectivity.setConnected(false);
      await tester.pump();
      await tester.pump();
      expect(
        find.text("You're offline. Check your internet connection."),
        findsOneWidget,
      );
      connectivity.setConnected(true);
      await tester.pump();
      await tester.pump();
      expect(find.text("You're back online."), findsOneWidget);
      expect(find.byKey(const Key('rehearsal_timer')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('12. Device Check reacts to internet changes', (tester) async {
    await setPhoneSize(tester);
    final connectivity = _FakeInternetConnectivity(false);
    addTearDown(connectivity.dispose);
    await openHome(tester, internetConnectivity: connectivity);
    await openSetup(tester);
    await enterValidSetup(tester, openPreview: false);

    expect(find.text('Not available'), findsOneWidget);
    var startButton = find.byKey(const Key('start_rehearsal'));
    expect(tester.widget<FilledButton>(startButton).onPressed, isNull);

    connectivity.setConnected(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Available'), findsOneWidget);
    expect(find.text("You're back online."), findsOneWidget);
    startButton = find.byKey(const Key('start_rehearsal'));
    expect(tester.widget<FilledButton>(startButton).onPressed, isNotNull);

    connectivity.setConnected(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Not available'), findsOneWidget);
    expect(
      find.text("You're offline. Check your internet connection."),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(startButton).onPressed, isNull);
  });

  testWidgets('Connection messages follow navigation and do not repeat', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final connectivity = _FakeInternetConnectivity(true);
    addTearDown(connectivity.dispose);
    await openHome(tester, internetConnectivity: connectivity);
    await tester.pump(const Duration(seconds: 4));
    connectivity.setConnected(false);
    await tester.pump();
    await tester.pump();
    expect(
      find.text("You're offline. Check your internet connection."),
      findsOneWidget,
    );

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connection_notice')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    connectivity.setConnected(false);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('connection_notice')), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    connectivity.setConnected(true);
    await tester.pump();
    await tester.pump();
    expect(find.text("You're back online."), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('connection_notice')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    connectivity.setConnected(false);
    await tester.pump();
    expect(find.byKey(const Key('connection_notice')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(
      find.text("You're offline. Check your internet connection."),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
