import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/splash_onboarding.dart';
import 'state/app_state.dart';

class SpeakSyncApp extends StatelessWidget {
  const SpeakSyncApp({
    super.key,
    required this.appState,
    this.splashDuration = const Duration(seconds: 2),
    this.analysisDuration = const Duration(seconds: 2),
    this.deviceCheckDuration = const Duration(seconds: 1),
  });

  final AppState appState;
  final Duration splashDuration;
  final Duration analysisDuration;
  final Duration deviceCheckDuration;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: appState,
      child: AppTimingScope(
        splashDuration: splashDuration,
        analysisDuration: analysisDuration,
        deviceCheckDuration: deviceCheckDuration,
        child: MaterialApp(
          title: 'SpeakSync',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

class AppTimingScope extends InheritedWidget {
  const AppTimingScope({
    super.key,
    required this.splashDuration,
    required this.analysisDuration,
    required this.deviceCheckDuration,
    required super.child,
  });

  final Duration splashDuration;
  final Duration analysisDuration;
  final Duration deviceCheckDuration;

  static AppTimingScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppTimingScope>()!;
  }

  @override
  bool updateShouldNotify(AppTimingScope oldWidget) {
    return splashDuration != oldWidget.splashDuration ||
        analysisDuration != oldWidget.analysisDuration ||
        deviceCheckDuration != oldWidget.deviceCheckDuration;
  }
}
