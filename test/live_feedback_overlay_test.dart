import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/camera_framing.dart';
import 'package:speaksync_prototype/services/camera_framing_warning_controller.dart';
import 'package:speaksync_prototype/services/face_attention.dart';
import 'package:speaksync_prototype/services/posture_warning_controller.dart';
import 'package:speaksync_prototype/widgets/live_feedback_overlay.dart';

class _Feedback {
  final face = ValueNotifier(false);
  final missing = ValueNotifier<PostureWarningType?>(null);
  final posture = ValueNotifier<PostureWarningType?>(null);
  final framing = ValueNotifier<CameraFramingState?>(null);
  final faceController = FaceAttentionWarningController();
  final postureController = PostureWarningController();
  final framingController = CameraFramingWarningController();

  Widget widget({
    bool enabled = true,
    bool visual = true,
    bool body = true,
    bool attention = true,
    String? temporary,
    String? system,
  }) => LiveFeedbackOverlay(
    enabled: enabled,
    visualEnabled: visual,
    monitorBodyLanguage: body,
    monitorCameraAttention: attention,
    faceWarning: face,
    faceMissingWarning: missing,
    postureWarning: posture,
    framingWarning: framing,
    temporaryMessage: temporary,
    systemMessage: system,
  );

  void dispose() {
    face.dispose();
    missing.dispose();
    posture.dispose();
    framing.dispose();
  }
}

Future<void> _mount(
  WidgetTester tester,
  Widget overlay, {
  Size size = const Size(320, 500),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: SizedBox(
              key: const Key('preview'),
              width: size.width,
              height: size.height,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Colors.black)),
                  Positioned.fill(child: overlay),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: TextButton(
                      key: const Key('control'),
                      onPressed: () {},
                      child: const Text('Camera'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _Feedback feedback;
  setUp(() => feedback = _Feedback());
  tearDown(() => feedback.dispose());

  testWidgets('simultaneous warnings are silent stacked cards inside preview', (
    tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    feedback.face.value = true;
    feedback.posture.value = PostureWarningType.adjustPosture;
    feedback.framing.value = CameraFramingState.tooClose;
    await _mount(tester, feedback.widget(temporary: 'Filler detected: kuan'));
    final frame = tester.getRect(find.byKey(const Key('preview')));
    var lastBottom = frame.top;
    for (final message in [
      'Please face the camera',
      'Adjust your posture',
      'Move farther from the camera',
      'Filler detected: kuan',
    ]) {
      final finder = find.text(message);
      expect(finder, findsOneWidget);
      final card = tester.getRect(finder);
      expect(frame.contains(card.topLeft), isTrue);
      expect(frame.contains(card.bottomRight), isTrue);
      expect(card.top, greaterThan(lastBottom));
      lastBottom = card.bottom;
    }
    expect(
      tester.getRect(find.byKey(const Key('live_feedback_overlay'))).top,
      frame.top + 8,
    );
    expect(
      platformCalls.where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' ||
            call.method == 'SystemSound.play',
      ),
      isEmpty,
    );
    // Normal button tap feedback is unrelated to warning notifications.
    await tester.tap(find.byKey(const Key('control')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('posture persists through a short good interval then recovers', (
    tester,
  ) async {
    await _mount(tester, feedback.widget());
    for (var ms = 0; ms <= 3000; ms += 500) {
      feedback.posture.value = feedback.postureController
          .update(PostureWarningSignal.adjust, Duration(milliseconds: ms))
          .warning;
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Adjust your posture'), findsOneWidget);
    for (var ms = 3500; ms <= 5000; ms += 500) {
      feedback.posture.value = feedback.postureController
          .update(PostureWarningSignal.good, Duration(milliseconds: ms))
          .warning;
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Adjust your posture'), findsOneWidget);
    }
    feedback.posture.value = feedback.postureController
        .update(PostureWarningSignal.good, const Duration(milliseconds: 5500))
        .warning;
    await tester.pump();
    expect(find.text('Adjust your posture'), findsNothing);
  });

  testWidgets(
    'face warning retains existing three second and two second delays',
    (tester) async {
      await _mount(tester, feedback.widget());
      for (var ms = 0; ms < 3000; ms += 500) {
        feedback.face.value = feedback.faceController.update(
          FaceAttentionState.lookingAway,
          Duration(milliseconds: ms),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Please face the camera'), findsNothing);
      }
      feedback.face.value = feedback.faceController.update(
        FaceAttentionState.lookingAway,
        const Duration(seconds: 3),
      );
      await tester.pump();
      expect(find.text('Please face the camera'), findsOneWidget);
      for (var ms = 3500; ms <= 5000; ms += 500) {
        feedback.face.value = feedback.faceController.update(
          FaceAttentionState.facingCamera,
          Duration(milliseconds: ms),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Please face the camera'), findsOneWidget);
      }
      feedback.face.value = feedback.faceController.update(
        FaceAttentionState.facingCamera,
        const Duration(milliseconds: 5500),
      );
      await tester.pump();
      expect(find.text('Please face the camera'), findsNothing);
    },
  );

  for (final state in [
    CameraFramingState.tooClose,
    CameraFramingState.tooFar,
  ]) {
    testWidgets(
      '$state has persistent distance warning and consistent recovery',
      (tester) async {
        await _mount(tester, feedback.widget());
        feedback.framing.value = feedback.framingController.update(
          state,
          Duration.zero,
        );
        await tester.pump();
        expect(find.byKey(const Key('camera_framing_warning')), findsNothing);
        feedback.framing.value = feedback.framingController.update(
          state,
          const Duration(seconds: 3),
        );
        await tester.pump();
        expect(
          find.text(
            state == CameraFramingState.tooClose
                ? 'Move farther from the camera'
                : 'Move closer to the camera',
          ),
          findsOneWidget,
        );
        feedback.framing.value = feedback.framingController.update(
          CameraFramingState.proper,
          const Duration(seconds: 4),
        );
        feedback.framing.value = feedback.framingController.update(
          CameraFramingState.proper,
          const Duration(seconds: 5),
        );
        await tester.pump();
        expect(find.byKey(const Key('camera_framing_warning')), findsOneWidget);
        // One bad frame interrupts recovery, not persistence of the existing card.
        feedback.framing.value = feedback.framingController.update(
          state,
          const Duration(milliseconds: 5500),
        );
        feedback.framing.value = feedback.framingController.update(
          CameraFramingState.proper,
          const Duration(seconds: 6),
        );
        feedback.framing.value = feedback.framingController.update(
          CameraFramingState.proper,
          const Duration(seconds: 8),
        );
        await tester.pump();
        expect(find.byKey(const Key('camera_framing_warning')), findsNothing);
      },
    );
  }

  testWidgets('missing face and body produce one position instruction', (
    tester,
  ) async {
    feedback.missing.value = PostureWarningType.positionYourself;
    feedback.posture.value = PostureWarningType.positionYourself;
    feedback.framing.value = CameraFramingState.unavailable;
    await _mount(tester, feedback.widget());
    expect(find.text('Position yourself in the camera view'), findsOneWidget);
    expect(find.text('Adjust your posture'), findsNothing);
    expect(find.text('Please face the camera'), findsNothing);
  });

  testWidgets('missing body warning waits for consistent landmark recovery', (
    tester,
  ) async {
    await _mount(tester, feedback.widget());
    feedback.posture.value = feedback.postureController
        .update(PostureWarningSignal.unavailable, Duration.zero)
        .warning;
    feedback.posture.value = feedback.postureController
        .update(PostureWarningSignal.unavailable, const Duration(seconds: 3))
        .warning;
    await tester.pump();
    expect(find.text('Position yourself in the camera view'), findsOneWidget);
    feedback.posture.value = feedback.postureController
        .update(PostureWarningSignal.good, const Duration(seconds: 4))
        .warning;
    feedback.posture.value = feedback.postureController
        .update(PostureWarningSignal.good, const Duration(seconds: 5))
        .warning;
    await tester.pump();
    expect(find.text('Position yourself in the camera view'), findsOneWidget);
    feedback.posture.value = feedback.postureController
        .update(PostureWarningSignal.good, const Duration(seconds: 6))
        .warning;
    await tester.pump();
    expect(find.text('Position yourself in the camera view'), findsNothing);
  });

  testWidgets('Live Feedback OFF hides every card including temporary alerts', (
    tester,
  ) async {
    feedback.face.value = true;
    feedback.posture.value = PostureWarningType.adjustPosture;
    feedback.framing.value = CameraFramingState.tooClose;
    await _mount(
      tester,
      feedback.widget(enabled: false, temporary: 'Filler detected: kuan'),
    );
    expect(find.byKey(const Key('live_feedback_overlay')), findsNothing);
  });

  testWidgets(
    'operational notices survive disabled monitoring and Live Feedback',
    (tester) async {
      feedback.face.value = true;
      feedback.posture.value = PostureWarningType.adjustPosture;
      for (final message in [
        'Recording failed',
        'Camera permission required',
        'Internet unavailable',
        'Recording saved locally.',
      ]) {
        await _mount(
          tester,
          feedback.widget(
            enabled: false,
            body: false,
            attention: false,
            temporary: 'Filler detected: kuan',
            system: message,
          ),
        );
        expect(find.text(message), findsOneWidget);
        expect(find.text('Please face the camera'), findsNothing);
        expect(find.text('Adjust your posture'), findsNothing);
        expect(find.text('Filler detected: kuan'), findsNothing);
      }
    },
  );

  testWidgets(
    'operational notice and performance alerts coexist without replacement',
    (tester) async {
      feedback.face.value = true;
      await _mount(
        tester,
        feedback.widget(
          system: 'Recording failed',
          temporary: 'Filler detected: kuan',
        ),
      );
      expect(find.text('Recording failed'), findsOneWidget);
      expect(find.text('Filler detected: kuan'), findsOneWidget);
      expect(find.text('Please face the camera'), findsOneWidget);
      await _mount(tester, feedback.widget(system: 'Recording failed'));
      expect(find.text('Recording failed'), findsOneWidget);
      expect(find.text('Please face the camera'), findsOneWidget);
    },
  );

  testWidgets('monitoring toggles independently hide their warnings', (
    tester,
  ) async {
    feedback.face.value = true;
    feedback.posture.value = PostureWarningType.adjustPosture;
    feedback.framing.value = CameraFramingState.tooFar;
    await _mount(tester, feedback.widget(body: false));
    expect(find.text('Please face the camera'), findsOneWidget);
    expect(find.text('Adjust your posture'), findsNothing);
    expect(find.byKey(const Key('camera_framing_warning')), findsNothing);
    await _mount(tester, feedback.widget(attention: false));
    expect(find.text('Please face the camera'), findsNothing);
    expect(find.text('Adjust your posture'), findsOneWidget);
    await _mount(
      tester,
      feedback.widget(visual: false, temporary: 'Filler detected: kuan'),
    );
    expect(find.text('Adjust your posture'), findsNothing);
    expect(find.text('Filler detected: kuan'), findsOneWidget);
  });

  testWidgets(
    'removing a temporary speech event does not remove visual warnings',
    (tester) async {
      feedback.face.value = true;
      await _mount(tester, feedback.widget(temporary: 'Filler detected: kuan'));
      await _mount(tester, feedback.widget());
      expect(find.text('Filler detected: kuan'), findsNothing);
      expect(find.text('Please face the camera'), findsOneWidget);
    },
  );

  for (final size in [
    const Size(288, 512),
    const Size(460, 258),
    const Size(288, 162),
    const Size(720, 405),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('all warnings fit $size with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        feedback.face.value = true;
        feedback.posture.value = PostureWarningType.adjustPosture;
        feedback.framing.value = CameraFramingState.tooClose;
        await _mount(
          tester,
          feedback.widget(temporary: 'Filler detected: kuan'),
          size: size,
          textScale: scale,
        );
        final frame = tester.getRect(find.byKey(const Key('preview')));
        final overlay = tester.getRect(
          find.byKey(const Key('live_feedback_overlay')),
        );
        expect(frame.contains(overlay.topLeft), isTrue);
        expect(frame.contains(overlay.bottomRight), isTrue);
        expect(overlay.width, lessThanOrEqualTo(360));
        expect(
          overlay.bottom,
          lessThan(tester.getRect(find.byKey(const Key('control'))).top),
        );
        // Short previews remain usable: scroll to every card instead of clipping.
        final scroll = find.descendant(
          of: find.byKey(const Key('live_feedback_overlay')),
          matching: find.byType(SingleChildScrollView),
        );
        await tester.drag(scroll, const Offset(0, -400));
        await tester.pump();
        expect(
          find.text('Filler detected: kuan').hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('control')));
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('framing invalidity and reset never retain an old distance warning', () {
    final controller = feedback.framingController;
    controller.update(CameraFramingState.tooClose, Duration.zero);
    expect(
      controller.update(
        CameraFramingState.tooClose,
        const Duration(seconds: 3),
      ),
      CameraFramingState.tooClose,
    );
    expect(
      controller.update(
        CameraFramingState.unavailable,
        const Duration(seconds: 4),
      ),
      isNull,
    );
    expect(
      controller.update(
        CameraFramingState.unavailable,
        const Duration(seconds: 7),
      ),
      CameraFramingState.unavailable,
    );
    controller.reset();
    expect(controller.warning, isNull);
    expect(
      controller.update(CameraFramingState.tooClose, Duration.zero),
      isNull,
    );
  });
}
