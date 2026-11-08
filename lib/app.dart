import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'core/app_theme.dart';
import 'login.dart';
import 'register.dart';
import 'screens/authenticated_home.dart';
import 'screens/splash_onboarding.dart';
import 'services/internet_connectivity_service.dart';
import 'services/groq_transcription_service.dart';
import 'services/rehearsal_audio_recorder.dart';
import 'state/app_state.dart';
import 'widgets/connection_notice.dart';

class SpeakSyncApp extends StatelessWidget {
  const SpeakSyncApp({
    super.key,
    required this.appState,
    required this.authService,
    this.splashDuration = const Duration(seconds: 2),
    this.analysisDuration = const Duration(seconds: 2),
    this.deviceCheckDuration = const Duration(seconds: 1),
    this.internetConnectivity = const InternetConnectivityService(),
    this.enforceDeviceReadiness = true,
    this.rehearsalAudioRecorderFactory,
    this.liveTranscriptionService,
  });

  final AppState appState;
  final AuthService authService;
  final Duration splashDuration;
  final Duration analysisDuration;
  final Duration deviceCheckDuration;
  final InternetConnectivity internetConnectivity;
  final bool enforceDeviceReadiness;
  final RehearsalAudioRecorder Function()? rehearsalAudioRecorderFactory;
  final GroqTranscriptionService? liveTranscriptionService;

  @override
  Widget build(BuildContext context) {
    return AuthServiceScope(
      service: authService,
      child: AppStateScope(
        notifier: appState,
        child: AppTimingScope(
          splashDuration: splashDuration,
          analysisDuration: analysisDuration,
          deviceCheckDuration: deviceCheckDuration,
          internetConnectivity: internetConnectivity,
          enforceDeviceReadiness: enforceDeviceReadiness,
          rehearsalAudioRecorderFactory: rehearsalAudioRecorderFactory,
          liveTranscriptionService: liveTranscriptionService,
          child: MaterialApp(
            title: 'SpeakSync',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            builder: (context, child) => ConnectionNotice(
              connectivity: internetConnectivity,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const SplashScreen(),
            routes: {
              '/home': (context) => const AuthenticatedHome(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
            },
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------

class AppTimingScope extends InheritedWidget {
  const AppTimingScope({
    super.key,
    required this.splashDuration,
    required this.analysisDuration,
    required this.deviceCheckDuration,
    required this.internetConnectivity,
    this.enforceDeviceReadiness = true,
    this.rehearsalAudioRecorderFactory,
    this.liveTranscriptionService,
    required super.child,
  });

  final Duration splashDuration;
  final Duration analysisDuration;
  final Duration deviceCheckDuration;
  final InternetConnectivity internetConnectivity;
  final bool enforceDeviceReadiness;
  final RehearsalAudioRecorder Function()? rehearsalAudioRecorderFactory;
  final GroqTranscriptionService? liveTranscriptionService;

  static AppTimingScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppTimingScope>()!;
  }

  @override
  bool updateShouldNotify(AppTimingScope oldWidget) {
    return splashDuration != oldWidget.splashDuration ||
        analysisDuration != oldWidget.analysisDuration ||
        deviceCheckDuration != oldWidget.deviceCheckDuration ||
        internetConnectivity != oldWidget.internetConnectivity ||
        enforceDeviceReadiness != oldWidget.enforceDeviceReadiness ||
        rehearsalAudioRecorderFactory !=
            oldWidget.rehearsalAudioRecorderFactory ||
        liveTranscriptionService != oldWidget.liveTranscriptionService;
  }
}
