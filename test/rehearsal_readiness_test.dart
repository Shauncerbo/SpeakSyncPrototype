import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/core/app_config.dart';
import 'package:speaksync_prototype/models/practice_settings.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/services/internet_connectivity_service.dart';
import 'package:speaksync_prototype/services/rehearsal_audio_recorder.dart';
import 'package:speaksync_prototype/state/app_state.dart';

class _Online implements InternetConnectivity {
  @override
  Future<bool> check() async => true;
  @override
  Stream<bool> get statusChanges => const Stream.empty();
}

class _Recorder implements RehearsalAudioRecorder {
  int starts = 0;
  int cancellations = 0;
  bool disposed = false;
  bool started = false;
  Completer<void>? startGate;

  @override
  bool get hasStarted => started;
  @override
  Stream<double> get levels => const Stream.empty();
  @override
  Future<void> start() async {
    starts++;
    await startGate?.future;
    started = true;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
    started = false;
  }

  @override
  Future<void> dispose() async => disposed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<AppState> preview(WidgetTester tester, _Recorder recorder) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.reset);
    final state = AppState();
    state.setCurrentSetup(
      const PracticeSettings(
        speechTitle: 'Readiness test',
        speechType: 'Impromptu',
        languageMode: 'Mixed Language',
        selectedDuration: '1 minute',
        monitorBodyLanguage: true,
        monitorCameraAttention: true,
        monitorFillers: true,
        monitorPace: true,
        enableLiveFeedback: true,
      ),
    );
    await tester.pumpWidget(
      AppStateScope(
        notifier: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RehearsalScreen(
                      internetConnectivity: _Online(),
                      audioRecorder: recorder,
                    ),
                  ),
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets(
    'Microphone does not start until all three countdown seconds pass',
    (tester) async {
      final recorder = _Recorder();
      await preview(tester, recorder);
      await tester.pump(const Duration(minutes: 2));
      expect(recorder.starts, 0);
      expect(find.text('REC'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
      await tester.tap(find.byKey(const Key('ready_rehearsal')));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        expect(recorder.starts, 0);
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump();
      expect(recorder.starts, AppConfig.hasGroqApiKey ? 1 : 0);
      expect(find.text('01:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(recorder.disposed, isTrue);
    },
  );

  // Run with --dart-define=GROQ_API_KEY=readiness-test-placeholder.
  // The injected recorder prevents hardware access; no transcript is requested.
  testWidgets(
    'Back during microphone startup discards audio and saves nothing',
    (tester) async {
      final recorder = _Recorder()..startGate = Completer<void>();
      final state = await preview(tester, recorder);
      final savedCount = state.sessions.length;
      await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
      await tester.tap(find.byKey(const Key('ready_rehearsal')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(recorder.starts, 1);
      expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      recorder.startGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(recorder.cancellations, 1);
      expect(recorder.disposed, isTrue);
      expect(state.currentReport, isNull);
      expect(state.sessions.length, savedCount);
      expect(find.text('Open preview'), findsOneWidget);
    },
    skip: !AppConfig.hasGroqApiKey,
  );
}
