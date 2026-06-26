import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'state/app_state.dart';
import 'login.dart'; 

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
          
          // 2. CHANGE THIS FROM SplashScreen() TO LoginScreen()
          home: const LoginScreen(), 

          // 3. ADD THIS ROUTES BLOCK
          // This prevents the app from crashing when you press the "Sign In" button!
          routes: {
            '/home': (context) => const DummyDashboardScreen(), 
          },
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. A TEMPORARY TEMPLATE HOME SCREEN 
// This gives your successful login a place to land until you build your real dashboard!
class DummyDashboardScreen extends StatelessWidget {
  const DummyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SpeakSync Dashboard')),
      body: const Center(
        child: Text(
          'Welcome to the SpeakSync Dashboard!\n(Success: Login Bypassed Successfully)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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