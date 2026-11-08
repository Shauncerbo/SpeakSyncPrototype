import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/app.dart';
import 'package:speaksync_prototype/models/practice_settings.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/services/internet_connectivity_service.dart';
import 'package:speaksync_prototype/state/app_state.dart';

class _Online implements InternetConnectivity {
  @override
  Future<bool> check() async => true;

  @override
  Stream<bool> get statusChanges => const Stream.empty();
}

void main() {
  Future<void> pumpCheck(
    WidgetTester tester, {
    required bool camera,
    required bool microphone,
  }) async {
    final state = AppState()
      ..setCurrentSetup(
        const PracticeSettings(
          speechTitle: 'Device readiness',
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
        child: AppTimingScope(
          splashDuration: Duration.zero,
          analysisDuration: Duration.zero,
          deviceCheckDuration: Duration.zero,
          internetConnectivity: _Online(),
          enforceDeviceReadiness: true,
          child: MaterialApp(
            home: DeviceCheckScreen(
              cameraAvailabilityCheck: () async => camera,
              microphoneAvailabilityCheck: () async => microphone,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('unavailable camera and microphone block camera preview', (
    tester,
  ) async {
    await pumpCheck(tester, camera: false, microphone: false);

    expect(
      find.textContaining('Camera not detected or unavailable'),
      findsOneWidget,
    );
    expect(find.textContaining('Microphone unavailable'), findsWidgets);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('start_rehearsal')),
    );
    expect(button.onPressed, isNull);
    expect(find.byKey(const Key('open_device_permissions')), findsOneWidget);
  });

  testWidgets('usable camera and microphone allow camera preview', (
    tester,
  ) async {
    await pumpCheck(tester, camera: true, microphone: true);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('start_rehearsal')),
    );
    expect(button.onPressed, isNotNull);
  });
}
