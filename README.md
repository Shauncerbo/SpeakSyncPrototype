# SpeakSync Flutter Front-End Prototype

SpeakSync is a mobile-first speech and body-language rehearsal prototype for Senior High School students. It demonstrates localized Filipino-Bisaya filler-word feedback, speaking-pace coaching, posture awareness, camera attention, reports, and progress tracking through a polished simulated experience.

## Prototype scope

This version is a front-end prototype only. AI analysis, backend services, APIs, authentication, and database integration are simulated or not yet implemented.

The application does not access a real camera or microphone, record audio or video, upload content, connect to a backend, or require an internet connection. All practice results and history changes use local dummy data and remain in memory only while the app is open.

## Technologies

- Flutter 3 and Dart
- Material 3
- `ChangeNotifier` with an `InheritedNotifier` app state
- Navigator-based mobile flows
- Built-in Flutter widgets and `CustomPainter`
- Flutter widget tests

## Completed features

- Timed splash and three-page onboarding
- Home dashboard with practice summaries, coaching, and privacy reminders
- Validated practice setup with speech, language, duration, and monitoring options
- Simulated camera, microphone, lighting, framing, and internet checks
- Rehearsal timer with pause, resume, and safe disposal
- Simulated camera preview and microphone activity
- Demo controls for Kuan, Ano, poor posture, looking away, fast pace, and good performance
- Auto-hiding, non-flashing feedback alerts
- Dynamic simulated scoring and performance reports
- In-memory report saving with duplicate prevention
- Progress metrics, custom trend chart, session history, and session details
- Practice preferences, privacy details, help, about, and prototype data reset
- Responsive scrolling layouts designed for 360–430 logical pixel mobile widths
- Android and web project targets

## Simulated features

- Camera preview and upper-body visibility
- Microphone activity
- Speech processing and filler-word detection
- Pace, posture, and camera-attention analysis
- Device readiness and internet availability
- Performance scores and coaching tips

## Folder structure

```text
lib/
  main.dart
  app.dart
  core/
    app_theme.dart
  data/
    dummy_data.dart
  models/
    app_preferences.dart
    practice_session.dart
    practice_settings.dart
  screens/
    home_screen.dart
    main_shell.dart
    practice_flow.dart
    progress_screens.dart
    settings_screens.dart
    splash_onboarding.dart
  state/
    app_state.dart
  widgets/
    common_widgets.dart
test/
  widget_test.dart
```

## Setup

1. Install Flutter and verify the toolchain with `flutter doctor`.
2. Open this project directory.
3. Fetch dependencies:

   ```bash
   flutter pub get
   ```

4. Run the application:

   ```bash
   flutter run
   ```

For a browser preview, select a web device or run `flutter run -d chrome`.

## Quality commands

```bash
dart format .
flutter analyze
flutter test
```
