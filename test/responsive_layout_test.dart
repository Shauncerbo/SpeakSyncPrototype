import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/app.dart';
import 'package:speaksync_prototype/core/app_theme.dart';
import 'package:speaksync_prototype/data/dummy_data.dart';
import 'package:speaksync_prototype/login.dart';
import 'package:speaksync_prototype/register.dart';
import 'package:speaksync_prototype/models/practice_settings.dart';
import 'package:speaksync_prototype/screens/main_shell.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/screens/progress_screens.dart';
import 'package:speaksync_prototype/screens/settings_screens.dart';
import 'package:speaksync_prototype/screens/splash_onboarding.dart';
import 'package:speaksync_prototype/services/internet_connectivity_service.dart';
import 'package:speaksync_prototype/state/app_state.dart';

class _Online implements InternetConnectivity {
  @override
  Future<bool> check() async => true;
  @override
  Stream<bool> get statusChanges => const Stream.empty();
}

void main() {
  final sizes = <String, Size>{
    'small Android': const Size(320, 568),
    'large Android': const Size(412, 915),
    'Android tablet': const Size(800, 1280),
    'small iPhone': const Size(375, 667),
    'iPhone': const Size(390, 844),
    'iPad': const Size(768, 1024),
    'iPad Pro': const Size(1024, 1366),
    'small Android large text': const Size(320, 568),
    'iPad large text': const Size(768, 1024),
  };
  final screens = <String, Widget Function()>{
    'splash': () => const SplashScreen(),
    'onboarding': () => const OnboardingScreen(),
    'login': () => const LoginScreen(),
    'register': () => const RegisterScreen(),
    'login keyboard': () => const LoginScreen(),
    'register keyboard': () => const RegisterScreen(),
    'home': () => const MainShell(),
    'progress': () => const MainShell(initialIndex: 1),
    'settings': () => const MainShell(initialIndex: 2),
    'privacy dialog': () => const MainShell(initialIndex: 2),
    'setup': () => const PracticeSetupScreen(),
    'device check': () => const DeviceCheckScreen(),
    'preview': () => RehearsalScreen(internetConnectivity: _Online()),
    'rehearsal': () => RehearsalScreen(internetConnectivity: _Online()),
    'analyzing': () => const AnalyzingScreen(
      transcriptionErrorMessage:
          'Transcript unavailable. Check your internet connection and try again.',
    ),
    'report': () => const ReportScreen(),
    'session details': () =>
        SessionDetailsScreen(session: initialSessions().first),
    'about': () => const AboutScreen(),
  };
  for (final device in sizes.entries) {
    for (final landscape in [false, true]) {
      for (final screen in screens.entries) {
        testWidgets(
          '${device.key} ${landscape ? "landscape" : "portrait"}: ${screen.key}',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = landscape
                ? Size(device.value.height, device.value.width)
                : device.value;
            addTearDown(tester.view.reset);
            final state = AppState()..setCurrentReport(initialSessions().first);
            state.setCurrentSetup(
              const PracticeSettings(
                speechTitle:
                    'A speech about improving communication in our community',
                speechType: 'Impromptu',
                languageMode: 'Mixed Language',
                selectedDuration: '3 minutes',
                monitorBodyLanguage: true,
                monitorCameraAttention: true,
                monitorFillers: true,
                monitorPace: true,
                enableLiveFeedback: true,
              ),
            );
            final errorHandler = FlutterError.onError;
            FlutterError.onError = (details) {
              debugPrint(details.toString());
              errorHandler?.call(details);
            };
            addTearDown(() => FlutterError.onError = errorHandler);
            await tester.pumpWidget(
              AppStateScope(
                notifier: state,
                child: AppTimingScope(
                  splashDuration: const Duration(days: 1),
                  analysisDuration: const Duration(days: 1),
                  deviceCheckDuration: Duration.zero,
                  internetConnectivity: _Online(),
                  child: MaterialApp(
                    theme: buildAppTheme().copyWith(
                      platform: device.key.contains('iP')
                          ? TargetPlatform.iOS
                          : TargetPlatform.android,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(
                          device.key.contains('large text') ? 1.5 : 1,
                        ),
                        padding: landscape
                            ? const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              )
                            : const EdgeInsets.only(top: 24, bottom: 24),
                      ),
                      child: child!,
                    ),
                    home: screen.value(),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));
            if (screen.key.endsWith('keyboard')) {
              tester.view.viewInsets = const FakeViewPadding(bottom: 180);
              await tester.pump();
              await tester.ensureVisible(find.byType(TextFormField).last);
              await tester.pump();
            }
            if (screen.key == 'privacy dialog') {
              await tester.ensureVisible(find.text('View Privacy Details'));
              await tester.tap(find.text('View Privacy Details'));
              await tester.pump(const Duration(milliseconds: 300));
            }
            if (screen.key == 'rehearsal') {
              await tester.ensureVisible(
                find.byKey(const Key('ready_rehearsal')),
              );
              await tester.tap(find.byKey(const Key('ready_rehearsal')));
              await tester.pump();
              await tester.pump(const Duration(seconds: 3));
              await tester.pump();
            }
            if (screen.key == 'preview' || screen.key == 'rehearsal') {
              final frame = find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label ==
                        'Live rehearsal camera. Keep your face and waist visible.',
              );
              final size = tester.getSize(frame);
              expect(
                size.width / size.height,
                closeTo(landscape ? 16 / 9 : 9 / 16, .001),
              );
              expect(size.width, lessThanOrEqualTo(landscape ? 720 : 430));
              if (landscape) {
                expect(size.height, lessThan(tester.view.physicalSize.height));
              }
              if (screen.key == 'rehearsal') {
                final meter = find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.label == 'Microphone inactive',
                );
                expect(
                  tester.getRect(frame).contains(tester.getCenter(meter)),
                  isTrue,
                );
                expect(
                  tester
                      .getSize(find.byKey(const Key('toggle_microphone')))
                      .height,
                  greaterThanOrEqualTo(48),
                );
              }
            }
            FlutterError.onError = errorHandler;
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          },
        );
      }
    }
  }
}
