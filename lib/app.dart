import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'register.dart';
import 'screens/main_shell.dart';
import 'screens/splash_onboarding.dart';
import 'services/internet_connectivity_service.dart';
import 'state/app_state.dart';
import 'widgets/connection_notice.dart';

class SpeakSyncApp extends StatelessWidget {
  const SpeakSyncApp({
    super.key,
    required this.appState,
    this.splashDuration = const Duration(seconds: 2),
    this.analysisDuration = const Duration(seconds: 2),
    this.deviceCheckDuration = const Duration(seconds: 1),
    this.internetConnectivity = const InternetConnectivityService(),
  });

  final AppState appState;
  final Duration splashDuration;
  final Duration analysisDuration;
  final Duration deviceCheckDuration;
  final InternetConnectivity internetConnectivity;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: appState,
      child: AppTimingScope(
        splashDuration: splashDuration,
        analysisDuration: analysisDuration,
        deviceCheckDuration: deviceCheckDuration,
        internetConnectivity: internetConnectivity,
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
            '/home': (context) => const MainShell(),
            '/register': (context) => const RegisterScreen(),
          },
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
    required super.child,
  });

  final Duration splashDuration;
  final Duration analysisDuration;
  final Duration deviceCheckDuration;
  final InternetConnectivity internetConnectivity;

  static AppTimingScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppTimingScope>()!;
  }

  @override
  bool updateShouldNotify(AppTimingScope oldWidget) {
    return splashDuration != oldWidget.splashDuration ||
        analysisDuration != oldWidget.analysisDuration ||
        deviceCheckDuration != oldWidget.deviceCheckDuration ||
        internetConnectivity != oldWidget.internetConnectivity;
  }
}
