import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speaksync_prototype/core/app_config.dart';
import 'package:speaksync_prototype/models/practice_settings.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/services/internet_connectivity_service.dart';
import 'package:speaksync_prototype/services/rehearsal_audio_recorder.dart';
import 'package:speaksync_prototype/services/screen_awake_service.dart';
import 'package:speaksync_prototype/services/ambient_noise_service.dart';
import 'package:speaksync_prototype/services/groq_transcription_service.dart';
import 'package:speaksync_prototype/services/live_filler_feedback_service.dart';
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
  Object? startError;
  int pauses = 0;
  int resumes = 0;
  final liveAudio = StreamController<Uint8List>.broadcast();
  bool? liveChunksRequested;

  @override
  bool get hasStarted => started;
  @override
  Stream<double> get levels => Stream.value(0);
  @override
  Future<void> start({bool enableLiveChunks = false}) async {
    starts++;
    liveChunksRequested = enableLiveChunks;
    if (startError != null) throw startError!;
    await startGate?.future;
    started = true;
  }

  @override
  Stream<Uint8List> get chunks => liveAudio.stream;

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  @override
  Duration get chunkDuration => RehearsalAudioRecorder.defaultLiveChunkDuration;

  @override
  Future<void> cancel() async {
    cancellations++;
    started = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await liveAudio.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LiveWhisper extends GroqTranscriptionService {
  _LiveWhisper(this.result) : super(apiKey: 'test-placeholder');
  final Future<String> Function() result;
  int requests = 0;

  @override
  Future<String> transcribe(String audioPath) async {
    requests++;
    return result();
  }
}

class _ScreenAwake implements ScreenAwakeController {
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async => enableCalls++;

  @override
  Future<void> disable() async => disableCalls++;
}

class _InMemoryLiveFeedback extends LiveFillerFeedbackService {
  _InMemoryLiveFeedback({
    required super.transcriber,
    super.onFiller,
    super.onPace,
    required super.chunkDuration,
  });

  @override
  void accept(Uint8List pcm) {
    unawaited(_process());
  }

  Future<void> _process() async {
    try {
      final transcript = await transcriber.transcribe('test-chunk.wav');
      handlePartialTranscript(transcript);
    } catch (_) {
      // A failed live chunk must not stop the screen timer.
    }
  }
}

class _Noise extends AmbientNoiseService {
  _Noise(this.result)
    : super(
        config: const AmbientNoiseConfig(refreshDelay: Duration(seconds: 3)),
      );
  AmbientNoiseResult result;
  int checks = 0;
  bool stopped = false;
  bool disposed = false;
  Completer<AmbientNoiseResult>? pending;
  Completer<void>? stopGate;

  @override
  Future<AmbientNoiseResult> check() async {
    checks++;
    stopped = false;
    return pending == null ? result : await pending!.future;
  }

  @override
  Future<void> stop() async {
    await stopGate?.future;
    stopped = true;
    if (pending != null && !pending!.isCompleted) {
      pending!.complete(const AmbientNoiseResult.unavailable('Interrupted'));
    }
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  var microphoneRequests = 0;
  setUp(() {
    microphoneRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          if (call.method == 'requestPermissions') {
            if ((call.arguments as List).contains(
              Permission.microphone.value,
            )) {
              microphoneRequests++;
            }
            return {for (final id in call.arguments as List) id: 0};
          }
          return 0;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, null);
  });

  Future<AppState> preview(
    WidgetTester tester,
    _Recorder recorder, {
    _Noise? noise,
    bool liveFeedback = true,
    bool monitorFillers = true,
    bool monitorPace = true,
    _LiveWhisper? liveWhisper,
    bool inMemoryLiveFeedback = false,
    _ScreenAwake? screenAwake,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.reset);
    final state = AppState();
    state.setCurrentSetup(
      PracticeSettings(
        speechTitle: 'Readiness test',
        speechType: 'Impromptu',
        languageMode: 'Mixed Language',
        selectedDuration: '1 minute',
        monitorBodyLanguage: true,
        monitorCameraAttention: true,
        monitorFillers: monitorFillers,
        monitorPace: monitorPace,
        enableLiveFeedback: liveFeedback,
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
                      ambientNoiseService: noise,
                      liveTranscriptionService: liveWhisper,
                      screenAwakeController: screenAwake ?? _ScreenAwake(),
                      liveFeedbackFactory: inMemoryLiveFeedback
                          ? (transcriber, onFiller, onPace, chunkDuration) =>
                                _InMemoryLiveFeedback(
                                  transcriber: transcriber,
                                  onFiller: onFiller,
                                  onPace: onPace,
                                  chunkDuration: chunkDuration,
                                )
                          : null,
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

  for (final level in AmbientNoiseLevel.values) {
    testWidgets('${level.name} noise status and start behavior', (
      tester,
    ) async {
      final noise = _Noise(AmbientNoiseResult(level: level, rms: 0.02));
      final recorder = _Recorder();
      await preview(tester, recorder, noise: noise, liveFeedback: false);
      expect(noise.checks, 1);
      final label = switch (level) {
        AmbientNoiseLevel.quiet => 'Quiet',
        AmbientNoiseLevel.moderate => 'Moderate',
        AmbientNoiseLevel.noisy => 'Noisy',
      };
      expect(find.text('Ambient noise: $label'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
      await tester.tap(find.byKey(const Key('ready_rehearsal')));
      await tester.pumpAndSettle();
      expect(noise.stopped, isTrue);
      expect(recorder.starts, 0);
      if (level == AmbientNoiseLevel.noisy) {
        expect(find.text('Noisy environment'), findsOneWidget);
        expect(find.byKey(const Key('readiness_countdown')), findsNothing);
        await tester.tap(find.text('Go back'));
        await tester.pumpAndSettle();
        expect(noise.checks, 2);
        await tester.tap(find.byKey(const Key('ready_rehearsal')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('continue_noisy_rehearsal')));
        await tester.pump();
      }
      expect(find.byKey(const Key('readiness_countdown')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('01:00'), findsOneWidget);
      expect(noise.checks, level == AmbientNoiseLevel.noisy ? 2 : 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(noise.disposed, isTrue);
    });
  }

  testWidgets('Denied microphone permission shows Unavailable safely', (
    tester,
  ) async {
    await preview(tester, _Recorder(), liveFeedback: false);
    expect(find.text('Ambient noise: Unavailable'), findsOneWidget);
    expect(
      find.text('Allow camera access to check your framing.'),
      findsOneWidget,
    );
    expect(find.textContaining('Microphone permission needed'), findsOneWidget);
    expect(find.byKey(const Key('ambient_noise_retry')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Ambient noise: Unavailable'), findsOneWidget);
    expect(microphoneRequests, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Backgrounding stops sampling without starting rehearsal', (
    tester,
  ) async {
    final noise = _Noise(const AmbientNoiseResult.unavailable('Unused'))
      ..pending = Completer<AmbientNoiseResult>();
    final recorder = _Recorder();
    await preview(tester, recorder, noise: noise);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(noise.stopped, isTrue);
    expect(recorder.starts, 0);
    expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(noise.checks, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'Noise changes automatically and stops refreshing for rehearsal',
    (tester) async {
      final noise = _Noise(
        const AmbientNoiseResult(level: AmbientNoiseLevel.quiet, rms: 0),
      );
      final recorder = _Recorder();
      await preview(tester, recorder, noise: noise);
      expect(find.text('Ambient noise: Quiet'), findsOneWidget);
      expect(find.byKey(const Key('ambient_noise_retry')), findsNothing);
      for (final level in [
        AmbientNoiseLevel.moderate,
        AmbientNoiseLevel.noisy,
        AmbientNoiseLevel.quiet,
      ]) {
        noise.result = AmbientNoiseResult(level: level, rms: 0.02);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        final label = level.name[0].toUpperCase() + level.name.substring(1);
        expect(find.text('Ambient noise: $label'), findsOneWidget);
        expect(recorder.starts, 0);
        expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
      }
      final checks = noise.checks;
      await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
      await tester.tap(find.byKey(const Key('ready_rehearsal')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(noise.checks, checks);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'Interrupted refresh retains Noisy warning and resumes after Go back',
    (tester) async {
      final noise = _Noise(
        const AmbientNoiseResult(level: AmbientNoiseLevel.noisy, rms: 0.1),
      );
      await preview(tester, _Recorder(), noise: noise);
      noise.pending = Completer<AmbientNoiseResult>();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Ambient noise: Noisy'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
      await tester.tap(find.byKey(const Key('ready_rehearsal')));
      await tester.pumpAndSettle();
      expect(find.text('Noisy environment'), findsOneWidget);
      final checks = noise.checks;
      noise.pending = null;
      noise.result = const AmbientNoiseResult(
        level: AmbientNoiseLevel.quiet,
        rms: 0,
      );
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('Ambient noise: Quiet'), findsOneWidget);
      expect(noise.checks, checks + 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('Unavailable noise input never blocks rehearsal', (tester) async {
    final noise = _Noise(
      const AmbientNoiseResult.unavailable('Microphone unavailable'),
    );
    await preview(tester, _Recorder(), noise: noise);
    expect(find.text('Ambient noise: Unavailable'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    expect(find.byKey(const Key('readiness_countdown')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'Unavailable input recovers automatically without a retry button',
    (tester) async {
      final noise = _Noise(const AmbientNoiseResult.unavailable('Input busy'));
      await preview(tester, _Recorder(), noise: noise);
      expect(find.text('Ambient noise: Unavailable'), findsOneWidget);
      noise.result = const AmbientNoiseResult(
        level: AmbientNoiseLevel.quiet,
        rms: 0,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('Ambient noise: Quiet'), findsOneWidget);
      expect(noise.checks, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('Cancelling countdown resumes automatic checks', (tester) async {
    final noise = _Noise(
      const AmbientNoiseResult(level: AmbientNoiseLevel.quiet, rms: 0),
    );
    await preview(tester, _Recorder(), noise: noise);
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(noise.checks, 1);
    noise.result = const AmbientNoiseResult(
      level: AmbientNoiseLevel.moderate,
      rms: 0.02,
    );
    await tester.tap(find.byKey(const Key('cancel_countdown')));
    await tester.pumpAndSettle();
    expect(noise.checks, 2);
    expect(find.text('Ambient noise: Moderate'), findsOneWidget);
    expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'Ready waits for noise shutdown before countdown, no time is counted',
    (tester) async {
      final noise = _Noise(const AmbientNoiseResult.unavailable('Unused'))
        ..pending = Completer<AmbientNoiseResult>()
        ..stopGate = Completer<void>();
      final recorder = _Recorder();
      await preview(tester, recorder, noise: noise);
      expect(find.text('Ambient noise: Checking...'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
      await tester.tap(find.byKey(const Key('ready_rehearsal')));
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('readiness_countdown')), findsNothing);
      expect(find.byKey(const Key('rehearsal_timer')), findsNothing);
      expect(recorder.starts, 0);
      noise.stopGate!.complete();
      await tester.pump();
      expect(find.byKey(const Key('readiness_countdown')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('01:00'), findsOneWidget);
      expect(noise.checks, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('Back during ambient sampling disposes mic and saves nothing', (
    tester,
  ) async {
    final noise = _Noise(const AmbientNoiseResult.unavailable('Unused'))
      ..pending = Completer<AmbientNoiseResult>();
    final recorder = _Recorder();
    final state = await preview(tester, recorder, noise: noise);
    final count = state.sessions.length;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(noise.disposed, isTrue);
    expect(noise.stopped, isTrue);
    expect(recorder.starts, 0);
    expect(state.sessions.length, count);
    expect(state.currentReport, isNull);
  });

  testWidgets(
    'Microphone does not start until all three countdown seconds pass',
    (tester) async {
      final recorder = _Recorder();
      final screenAwake = _ScreenAwake();
      await preview(tester, recorder, screenAwake: screenAwake);
      await tester.pump(const Duration(minutes: 2));
      expect(recorder.starts, 0);
      expect(screenAwake.enableCalls, 0);
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
      expect(screenAwake.enableCalls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(recorder.disposed, isTrue);
      expect(screenAwake.disableCalls, 1);
    },
  );

  // A configured fake recorder is essential: the original bug fired only
  // while _recording was true, regardless of whether input audio was silent.
  testWidgets(
    'Silent recording never emits automatic filler alerts or counts',
    (tester) async {
      final recorder = _Recorder();
      await preview(tester, recorder, liveFeedback: false);
      await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
      await tester.tap(find.byKey(const Key('ready_rehearsal')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(recorder.starts, 1);
      expect(recorder.hasStarted, isTrue);
      final fillerCard = find.byKey(const Key('filler_metric'));
      for (var second = 1; second <= 35; second++) {
        await tester.pump(const Duration(seconds: 1));
        expect(find.textContaining('Filler word detected'), findsNothing);
        expect(
          find.descendant(of: fillerCard, matching: find.text('After session')),
          findsOneWidget,
        );
      }
      expect(find.text('No fillers detected'), findsNothing);
      expect(find.byKey(const Key('test_camera_alert')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('camera_attention_metric')),
          matching: find.text('Unavailable'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    skip: !AppConfig.hasGroqApiKey,
  );

  testWidgets('Manual simulation controls are absent from student rehearsal', (
    tester,
  ) async {
    await preview(tester, _Recorder());
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const Key('prototype_alert_controls')), findsNothing);
    expect(find.byKey(const Key('test_filler_alert')), findsNothing);
    expect(find.byKey(const Key('test_fast_speech_alert')), findsNothing);
    expect(find.text('Test live alerts'), findsNothing);
    expect(find.text('82%'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('camera_attention_metric')),
        matching: find.text('Unavailable'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  Future<void> startRehearsal(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    expect(find.byKey(const Key('readiness_countdown')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump();
  }

  for (final error in [
    const AudioRecordingException('Microphone permission is required'),
    StateError('Recorder unavailable'),
  ]) {
    testWidgets('recording error $error is visible with Live Feedback OFF', (
      tester,
    ) async {
      final recorder = _Recorder()..startError = error;
      await preview(
        tester,
        recorder,
        liveFeedback: false,
        liveWhisper: _LiveWhisper(() async => 'Unused'),
      );
      await startRehearsal(tester);
      final notice = find.byKey(const Key('system_rehearsal_alert'));
      expect(notice, findsOneWidget);
      expect(
        find.descendant(
          of: notice,
          matching: find.text(
            error is AudioRecordingException
                ? error.message
                : 'SpeakSync could not start microphone recording.',
          ),
        ),
        findsOneWidget,
      );
      expect(recorder.liveChunksRequested, isFalse);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(notice, findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('camera permission warning survives Live Feedback OFF', (
    tester,
  ) async {
    await preview(
      tester,
      _Recorder(),
      liveFeedback: false,
      liveWhisper: _LiveWhisper(() async => 'Unused'),
    );
    await startRehearsal(tester);
    await tester.ensureVisible(find.byKey(const Key('toggle_camera')));
    await tester.tap(find.byKey(const Key('toggle_camera')));
    await tester.pump();
    expect(find.text('Camera is not ready yet.'), findsOneWidget);
    expect(find.byKey(const Key('system_rehearsal_alert')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('30-second reminder survives Live Feedback OFF', (tester) async {
    await preview(
      tester,
      _Recorder(),
      liveFeedback: false,
      liveWhisper: _LiveWhisper(() async => 'Unused'),
    );
    await startRehearsal(tester);
    await tester.pump(const Duration(seconds: 30));
    expect(find.textContaining('30 seconds remaining'), findsOneWidget);
    expect(find.byKey(const Key('temporary_rehearsal_alert')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('filler alert cannot overwrite a timed operational reminder', (
    tester,
  ) async {
    final recorder = _Recorder();
    await preview(
      tester,
      recorder,
      liveWhisper: _LiveWhisper(() async => 'Good morning, kuan, everyone.'),
      inMemoryLiveFeedback: true,
    );
    await startRehearsal(tester);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('30 seconds remaining'), findsOneWidget);
    expect(find.text('Filler detected: kuan'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.textContaining('30 seconds remaining'), findsNothing);
    expect(find.text('Filler detected: kuan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Filler detected: kuan'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'empty chunks and failures cannot leave live pace indefinitely stale',
    (tester) async {
      final recorder = _Recorder();
      var result = 'Good morning, kuan, everyone.';
      var fail = false;
      await preview(
        tester,
        recorder,
        liveWhisper: _LiveWhisper(() async {
          if (fail) throw StateError('Network unavailable');
          return result;
        }),
        inMemoryLiveFeedback: true,
      );
      await startRehearsal(tester);
      recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
      await tester.pump();
      expect(find.text('Pace: Slow'), findsOneWidget);
      result = '';
      await tester.pump(const Duration(seconds: 10));
      recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
      await tester.pump();
      expect(find.text('Pace: Slow'), findsOneWidget);
      fail = true;
      await tester.pump(const Duration(seconds: 10));
      recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
      await tester.pump();
      expect(find.text('Pace: Slow'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Pace: Slow'), findsNothing);
      expect(find.text('Listening...'), findsOneWidget);
      expect(find.byKey(const Key('rehearsal_timer')), findsOneWidget);
      fail = false;
      result = 'Good morning, kuan, everyone.';
      recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
      await tester.pump();
      expect(find.text('Pace: Slow'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'muting microphone clears outdated pace and filler alerts immediately',
    (tester) async {
      final recorder = _Recorder();
      await preview(
        tester,
        recorder,
        liveWhisper: _LiveWhisper(() async => 'Good morning, kuan, everyone.'),
        inMemoryLiveFeedback: true,
      );
      await startRehearsal(tester);
      recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
      await tester.pump();
      expect(find.text('Pace: Slow'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('toggle_microphone')));
      await tester.tap(find.byKey(const Key('toggle_microphone')));
      await tester.pump();
      expect(recorder.pauses, 1);
      expect(find.text('Pace: Slow'), findsNothing);
      expect(find.text('Filler detected: kuan'), findsNothing);
      await tester.tap(find.byKey(const Key('toggle_microphone')));
      await tester.pump();
      expect(recorder.resumes, 1);
      expect(find.text('Pace: Slow'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  // Run with --dart-define=GROQ_API_KEY=readiness-test-placeholder.
  // The injected recorder and in-memory processor prevent hardware or network access.
  testWidgets('one partial Whisper result updates filler alert and live pace', (
    tester,
  ) async {
    final recorder = _Recorder();
    final whisper = _LiveWhisper(() async => 'Good morning, kuan, everyone.');
    await preview(
      tester,
      recorder,
      liveWhisper: whisper,
      inMemoryLiveFeedback: true,
    );
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump();
    expect(recorder.liveChunksRequested, isTrue);
    expect(find.byKey(const Key('rehearsal_timer')), findsOneWidget);
    expect(recorder.liveAudio.hasListener, isTrue);
    recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
    await tester.pump();
    expect(whisper.requests, 1);
    expect(find.text('Filler detected: kuan'), findsOneWidget);
    final frame = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label ==
              'Live rehearsal camera. Keep your face and waist visible.',
    );
    expect(
      find.descendant(
        of: frame,
        matching: find.byKey(const Key('temporary_rehearsal_alert')),
      ),
      findsOneWidget,
    );
    final previewRect = tester.getRect(frame);
    final alertRect = tester.getRect(
      find.byKey(const Key('temporary_rehearsal_alert')),
    );
    expect(previewRect.contains(alertRect.topLeft), isTrue);
    expect(previewRect.contains(alertRect.bottomRight), isTrue);
    expect(find.text('Pace: Slow'), findsOneWidget);
    expect(find.text('24 WPM recent average'), findsOneWidget);
    expect(find.text('After session'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Filler detected: kuan'), findsNothing);
    expect(find.byKey(const Key('rehearsal_timer')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('failed live Whisper request leaves rehearsal timer running', (
    tester,
  ) async {
    final recorder = _Recorder();
    final whisper = _LiveWhisper(
      () async => throw const TranscriptionException(
        TranscriptionFailureType.apiFailure,
        'Rate limit',
      ),
    );
    await preview(
      tester,
      recorder,
      liveWhisper: whisper,
      inMemoryLiveFeedback: true,
    );
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('rehearsal_timer')), findsOneWidget);
    recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(whisper.requests, 1);
    expect(find.text('Filler detected: kuan'), findsNothing);
    expect(find.text('Listening...'), findsOneWidget);
    expect(find.text('00:56'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('live pace reuses chunks when filler monitoring is off', (
    tester,
  ) async {
    final recorder = _Recorder();
    final whisper = _LiveWhisper(() async => List.filled(20, 'word').join(' '));
    await preview(
      tester,
      recorder,
      monitorFillers: false,
      liveWhisper: whisper,
      inMemoryLiveFeedback: true,
    );
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(recorder.liveChunksRequested, isTrue);
    recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
    await tester.pump();
    expect(whisper.requests, 1);
    expect(find.text('Pace: Target'), findsOneWidget);
    expect(find.text('120 WPM recent average'), findsOneWidget);
    expect(find.textContaining('Filler detected:'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('live feedback disabled never requests live chunks', (
    tester,
  ) async {
    final recorder = _Recorder();
    final whisper = _LiveWhisper(() async => 'Kuan');
    await preview(tester, recorder, liveFeedback: false, liveWhisper: whisper);
    await tester.ensureVisible(find.byKey(const Key('ready_rehearsal')));
    await tester.tap(find.byKey(const Key('ready_rehearsal')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(recorder.liveChunksRequested, isFalse);
    recorder.liveAudio.add(Uint8List.fromList([1, 0, 2, 0]));
    await tester.pump(const Duration(seconds: 2));
    expect(whisper.requests, 0);
    expect(find.text('After session'), findsNWidgets(2));
    expect(find.text('Listening...'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

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
