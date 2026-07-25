# SpeakSync Flutter Front-End Prototype

SpeakSync is a mobile-first speech and body-language rehearsal prototype for Senior High School students. It demonstrates localized Filipino-Bisaya filler-word feedback, speaking-pace coaching, posture awareness, camera attention, reports, and progress tracking through a polished simulated experience.

## Prototype scope

This version remains an AI-analysis prototype. It uses the real device camera
preview, while speech, posture, pace, filler-word, transcript, and
camera-attention results remain simulated.

Completed reports, rehearsal metadata, filler logs, speech profiles, demo-user
data, and settings are persisted locally with Hive. The application does not
connect to a production backend or upload rehearsal content.

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
- Simulated camera, microphone, and internet readiness checks
- Target-duration countdown with a 30-second warning and automatic completion
- Real front-camera preview with camera and microphone controls
- Demo controls for Kuan, Ano, poor posture, looking away, fast pace, and good performance
- Auto-hiding, non-flashing feedback alerts
- Dynamic simulated scoring and performance reports
- Hive report saving with duplicate prevention and integrity validation
- Persisted progress metrics, ranking, trend chart, history, and details
- Monitoring preferences, privacy details, help, about, and prototype data reset
- Responsive scrolling layouts designed for 360–430 logical pixel mobile widths
- Android and web project targets

## Simulated features

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
    filler_word_log.dart
    performance_report.dart
    practice_session.dart
    practice_settings.dart
    rehearsal_session.dart
    speech_profile.dart
  screens/
    home_screen.dart
    main_shell.dart
    practice_flow.dart
    progress_screens.dart
    settings_screens.dart
    splash_onboarding.dart
  state/
    app_state.dart
  storage/
    hive_box_names.dart
    hive_repository.dart
  widgets/
    common_widgets.dart
test/
  hive_repository_test.dart
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
