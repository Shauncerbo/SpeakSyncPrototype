# SpeakSync System Overview

**Application:** SpeakSync  
**Current version:** Prototype 1.0.0  
**Document updated:** July 24, 2026  
**Technology:** Flutter and Dart  
**Primary target:** Android mobile devices  

## 1. System Summary

SpeakSync is a mobile-first public-speaking rehearsal application designed
primarily for Senior High School students. It helps a user prepare a speech,
rehearse in front of the device camera, review a performance report, and track
progress across multiple sessions.

The planned system focuses on:

- Speaking pace
- Filipino and Bisaya filler words
- Upper-body posture
- Camera-facing attention
- Session scores, transcripts, and coaching feedback
- Rehearsal history and performance trends

The current application is a working front-end prototype. It uses the real
device camera for the rehearsal preview, but its speech, posture, gaze, filler
word detection, transcript, and scores are simulated. There is no production
AI model or remote backend connected yet.

## 2. Current Implementation Status

| Area | Current status |
|---|---|
| Android application | Implemented |
| Web project | Configured |
| Splash and onboarding | Implemented |
| Login interface | Implemented, with temporary development bypass enabled |
| Registration interface | Implemented with in-memory mock registration |
| Real front-camera preview | Implemented |
| Camera permission request | Implemented |
| Camera on/off control | Implemented |
| Microphone on/off control | Visual prototype state only |
| Video recording code | Present, but the recording action is not connected to the current UI |
| Device readiness check | Simulated |
| Speech recognition | Not implemented |
| AI analysis | Not implemented |
| Filler-word detection | Simulated |
| Pace analysis | Simulated |
| Posture analysis | Simulated |
| Camera-attention analysis | Simulated |
| Performance report | Implemented with prototype scores |
| Progress and history | Implemented with persisted Hive records |
| Ranking details | Implemented; ranking cards open the full session report |
| User storage with Hive | Implemented for the current demo profile |
| Session and preference persistence | Implemented |
| Speech profiles, reports, and filler logs | Implemented with separate Hive boxes |
| Cloud database or API | Not implemented |

## 3. Intended Users

The main users are Senior High School students who want to improve their
delivery before:

- Classroom reports
- Oral presentations
- Prepared speeches
- Persuasive speeches
- Informative speeches
- Impromptu speaking activities

## 4. Main User Flow

```text
Launch app
   |
   v
Splash screen
   |
   v
Three-page onboarding
   |
   v
Login screen
   |  Sign In currently bypasses credential validation
   v
Home dashboard
   |
   v
Practice Setup
   |
   v
Simulated Device Check
   |
   v
Rehearsal with real camera preview
   |
   v
Simulated Analysis
   |
   v
Performance Report
   |
   +--> Save to Progress
   +--> Practice Again
   +--> Return Home
```

The main application has three bottom navigation destinations:

1. Home
2. Progress
3. Settings

## 5. Screen and Feature Inventory

### 5.1 Splash Screen

The splash screen displays the SpeakSync brand and automatically continues
after a short configured delay.

### 5.2 Onboarding

The onboarding flow contains three pages:

- Localized speech feedback
- Body-language awareness
- Private rehearsal

The user can move between pages or skip directly to the login screen.

### 5.3 Login

The login screen contains email and password inputs and a link to create an
account.

For faster development testing, `_bypassLoginForDevelopment` is currently set
to `true`. Pressing **Sign In** opens the home screen without checking the
entered account.

If the bypass is disabled, the current mock login accepts:

```text
Email: student@speaksync.com
Password: capstone123
```

This is not production authentication.

The login screen currently checks its own hard-coded credentials when the
bypass is disabled. It does not read accounts created by `AuthService`, so the
mock registration and mock login paths are not yet connected.

### 5.4 Registration

Registration collects:

- First name
- Optional middle name
- Last name
- Email
- Password
- Password confirmation

The current registration service still stores mock authentication accounts in
a static in-memory map. It is intentionally not production authentication and
is not the source of the active Hive demo profile.

### 5.5 Home Dashboard

The Home screen provides:

- Start Practice action
- Latest score
- Total session count
- Total practice time
- Latest score improvement
- Weekly practice goal summary
- Most recent session
- A coaching tip based on the latest session's weakest category

Selecting the latest score or recent session opens its detailed report.

### 5.6 Practice Setup

Before a rehearsal, the user provides:

- Speech title
- Optional prepared speech content or script
- Speech type
- Language mode
- Target duration

Supported speech types:

- Prepared
- Impromptu
- Informative
- Persuasive

Supported language modes:

- English
- English-Filipino
- English-Bisaya
- Mixed Language

Supported target durations:

- 1 minute
- 3 minutes
- 5 minutes
- 10 minutes
- No fixed duration

The user may enable or disable these monitoring options:

- Posture
- Camera-facing attention
- Filler words
- Speaking pace
- Live feedback

### 5.7 Device Check

The Device Check screen presents animated checks for:

- Camera
- Microphone
- Internet availability

These checks are currently simulated. They do not verify actual microphone
input or network connectivity. Lighting and upper-body feedback are not shown
because the rehearsal camera has not started on this screen.

### 5.8 Rehearsal

The rehearsal screen currently includes:

- Real front-camera preview
- Portrait camera frame intended to show the speaker's head and waist
- Minimum supported camera zoom for the widest available view
- Countdown timer for fixed target durations
- A 30-second remaining warning
- Automatic session completion when a fixed target reaches zero
- Elapsed timer when **No fixed duration** is selected
- Camera on/off button
- Microphone on/off button
- Microphone activity animation
- Live metric cards
- End-session confirmation
- Prototype buttons for testing posture, gaze, filler, and pace alerts

The application requests camera permission and selects the front-facing camera
when available. If there is no front camera, it uses the first available
camera.

The camera controller uses:

```text
Resolution: ResolutionPreset.max
Audio flag: enabled
Zoom: device minimum zoom level
```

Camera framing still depends on the physical camera lens, device orientation,
camera distance, and the minimum zoom supported by that phone.

The microphone control currently changes the user-interface state and activity
indicator. It does not perform speech recognition or audio analysis.

### 5.9 Analysis Screen

After ending a rehearsal, SpeakSync briefly displays an analysis screen. The
delay creates the intended report-generation experience, but no AI model is
executed during this step.

### 5.10 Performance Report

The report displays:

- Overall performance score
- Speaking pace score
- Filler-control score
- Posture score
- Camera-attention score
- Filler-word frequencies
- Prototype transcript
- Recommended posture
- Coaching tips

The report can be saved to Hive and then viewed from the Progress screen. A
duplicate check prevents the same completed session from being saved twice.

### 5.11 Progress and Rehearsal History

The Progress screen contains:

- Average score
- Total sessions
- Total practice time
- Performance trend chart
- Rehearsal ranking
- Improvement insight
- Weakest-area summary
- Session history

Rehearsals are ranked from highest to lowest overall score. Tapping a ranking
card or history card opens the complete Session Details screen.

Session Details includes:

- Overall score
- Category score breakdown
- The two strongest categories under **What you did well**
- Filler-word history
- Transcript
- Recommended posture
- Coaching tips
- Practice Again action

The application starts with four dummy rehearsal records:

| Rank by initial score | Rehearsal | Score |
|---|---|---:|
| 1 | Climate Change Speech | 82 |
| 2 | Technology and Education | 76 |
| 3 | Impromptu Practice | 71 |
| 4 | Environmental Awareness | 68 |

### 5.12 Settings and Privacy

The Settings screen supports:

- Posture-monitoring preference
- Camera-attention preference
- Filler-monitoring preference
- Pace-monitoring preference
- Real-time feedback preference
- Alert frequency
- Privacy information
- Saved-data information
- Help and instructions
- About SpeakSync
- Reset prototype data
- Log out

Preferences are saved to Hive as soon as they change and are restored on the
next application launch.

## 6. Scoring Logic

The current scores are prototype values and are not produced by real AI.

For a newly completed rehearsal, the overall score begins at 100 and applies
the following deductions:

```text
Overall score =
    100
    - (total filler count x 3)
    - 8 if posture is not Good
    - the camera-attention amount below 70
    - 8 if pace is Too Fast
```

The result is limited to the range 0 to 100.

Category scores currently use these rules:

| Category | Prototype calculation |
|---|---|
| Pace | 94 for Normal, otherwise 72 |
| Filler Control | 100 minus 7 for each filler, limited to 0-100 |
| Posture | 95 for Good, otherwise 72 |
| Camera Attention | Uses the current simulated attention percentage |

This calculation must eventually be replaced or validated using real audio,
speech, and computer-vision measurements.

## 7. Application Architecture

SpeakSync currently uses a simple Flutter architecture:

```text
UI Screens
   |
   v
AppStateScope (InheritedNotifier)
   |
   v
AppState (ChangeNotifier)
   |
   +--> Temporary PracticeSettings
   +--> UI-facing PracticeSession aggregates
   +--> Current report
   |
   v
HiveRepository
   |
   +--> User
   +--> AppPreferences
   +--> SpeechProfile
   +--> RehearsalSession
   +--> FillerWordLog
   +--> PerformanceReport
   `--> Application metadata
```

### State Management

`AppState` is a `ChangeNotifier` exposed through `AppStateScope`, an
`InheritedNotifier`. It coordinates:

- Current practice setup
- Current generated report
- Session aggregates loaded from Hive
- Application preferences

The UI listens to this shared state and rebuilds when it changes. Hive
operations are kept in `HiveRepository` rather than repeated in screens.

### Navigation

The application uses Flutter `Navigator` and `MaterialPageRoute`. The main
shell uses an `IndexedStack` so the Home, Progress, and Settings tab state
remains available while switching tabs.

## 8. Data Models

### PracticeSettings

Temporary choices for the next rehearsal:

- Speech title
- Optional prepared speech content
- Speech type
- Language mode
- Selected duration
- Monitoring toggles
- Live-feedback toggle

### PracticeSession

A completed rehearsal report:

- Unique ID
- Speech information
- Date and duration
- Overall and category scores
- Filler counts
- Coaching tips
- Transcript
- Gesture counts
- Recommended posture
- Prototype-data marker

### AppPreferences

Default user choices:

- Language and duration
- Monitoring defaults
- Live and vibration feedback
- Alert frequency

### User

The Hive user model contains:

- User ID
- First, middle, and last name
- Email
- Optional school
- Creation date

The previous password field has been removed from the Hive model and adapter.
Mock authentication remains separate and no password is written to Hive.

## 9. Storage and Persistence

Hive is initialized by `HiveRepository` when the app starts. All box names are
defined in one constants file, and one adapter is registered for every
persistent model.

Current storage behavior:

| Data | Storage |
|---|---|
| Initial rehearsal history | Seeded into Hive once when storage is empty |
| Newly saved reports | Hive `performanceReports` box |
| Rehearsal metadata | Hive `rehearsalSessions` box |
| Filler details | Hive `fillerWordLogs` box |
| Speech details | Hive `speechProfiles` box |
| Preferences | Hive `appPreferences` box |
| Demo user profile | Hive `users` box |
| Mock accounts | Static memory only |
| Recorded video | Recording code exists, but is not connected to the current UI |

Closing and reopening the app restores saved sessions, reports, rankings, and
preferences. A metadata flag prevents the four demo sessions from being seeded
more than once.

The UI continues to use `PracticeSession` as a safe aggregate model. The
repository reconstructs it by joining `RehearsalSession` with its
`PerformanceReport`. This preserves the existing Home, Progress, Ranking, and
Session Details interfaces.

## 10. Permissions and Privacy

The Android manifest requests:

- `android.permission.CAMERA`
- `android.permission.RECORD_AUDIO`

The rehearsal screen explicitly requests camera permission. The application
does not currently request microphone permission through
`permission_handler`, although the camera controller is configured with audio
enabled.

No production server upload is implemented. The prototype does not currently
send camera, audio, transcript, or report data to a remote service.

Before production, the system should add:

- Clear recording consent
- Microphone permission handling
- Secure user authentication
- Encrypted local storage
- A privacy policy and retention rules
- User-controlled deletion of recordings and reports
- Secure API transport if cloud AI is used

## 11. Main Dependencies

| Package | Purpose |
|---|---|
| `flutter` | Application framework |
| `cupertino_icons` | Additional icon set |
| `camera` | Device camera preview and recording support |
| `permission_handler` | Runtime camera permission |
| `hive` | Local NoSQL storage |
| `hive_flutter` | Flutter integration for Hive |
| `flutter_test` | Widget testing |
| `flutter_lints` | Static-analysis rules |
| `build_runner` | Code generation |
| `hive_generator` | Hive adapter generation |

## 12. Project Structure

```text
SpeakSyncPrototype/
|-- android/                     Android configuration and permissions
|-- docs/
|   |-- data_dictionary.md       Proposed local database structure
|   `-- SYSTEM_OVERVIEW.md       This document
|-- lib/
|   |-- core/
|   |   `-- app_theme.dart       Colors and application theme
|   |-- data/
|   |   `-- dummy_data.dart      Initial sessions and preferences
|   |-- models/
|   |   |-- app_preferences.dart
|   |   |-- practice_session.dart
|   |   |-- practice_settings.dart
|   |   `-- user_model.dart
|   |-- screens/
|   |   |-- home_screen.dart
|   |   |-- main_shell.dart
|   |   |-- practice_flow.dart
|   |   |-- progress_screens.dart
|   |   |-- settings_screens.dart
|   |   `-- splash_onboarding.dart
|   |-- state/
|   |   `-- app_state.dart
|   |-- widgets/
|   |   `-- common_widgets.dart
|   |-- app.dart                 Root widget, routes, and timing scope
|   |-- auth_service.dart        In-memory mock account service
|   |-- login.dart               Login interface and bypass
|   |-- main.dart                Hive startup and application entry point
|   `-- register.dart            Registration interface
|-- test/
|   `-- widget_test.dart
|-- web/                         Flutter web files
|-- pubspec.yaml                 Dependencies and project metadata
`-- README.md
```

`lib/screens/dashboard.dart` is a small legacy dashboard screen and is not part
of the current main navigation flow.

## 13. Running the Application

### Prerequisites

- Flutter SDK compatible with Dart `^3.11.3`
- Android Studio or Visual Studio Code
- Android SDK
- Android emulator or a USB-connected Android phone

### Install dependencies

```bash
flutter pub get
```

### Check connected devices

```bash
flutter devices
```

### Run on a real Android phone

```bash
flutter run -d <device-id>
```

The phone must have Developer Options and USB debugging enabled. Keep the USB
cable connected while using `flutter run`, unless wireless debugging has been
configured.

### Run on an Android emulator

```bash
flutter run -d emulator-5554
```

An emulator camera may use a virtual scene or the computer webcam and may not
match the field of view of a real phone.

### Run in Chrome

```bash
flutter run -d chrome
```

Browser camera access depends on browser permission and camera support.

## 14. Quality Checks

```bash
dart format .
flutter analyze
flutter test
```

The widget suite covers the current navigation and report flow. Repository
tests additionally verify persistence after closing and reopening Hive,
settings restoration, duplicate prevention, filler-log integrity, and
cascading prototype-data removal.

## 15. Known Prototype Limitations

1. Login validation is intentionally bypassed for faster development.
2. Authentication is local mock logic, not secure production authentication.
3. Mock registration/login is not connected to a real multi-user identity
   system; Hive currently uses a demo user profile.
4. Device readiness checks are animations, not hardware measurements.
5. Microphone activity is animated and does not represent real sound level.
6. Speech transcription is generated from fixed sample sentences.
7. Filler detection is simulated from those sample sentences or test buttons.
8. Posture and camera attention are simulated and do not use computer vision.
9. Video-recording code is present but not reachable from the current screen.
10. Scoring rules are prototype formulas rather than validated assessment
    models.
11. No remote API, cloud database, analytics service, or production AI is
    connected.
12. Some interface/help text may still describe older demo-control behavior.

## 16. Recommended Next Development Phases

### Phase 1: Stabilize the Prototype

- Update widget tests for the current navigation and login flow
- Remove or finish unused recording code
- Replace development `print` calls with proper logging
- Correct remaining stale help and privacy text
- Decide whether video recording is required

### Phase 2: Complete Identity and Data Management

- Connect registration and login to a safe account solution
- Associate the active authenticated user with their Hive records
- Add report deletion and data reset behavior
- Never store plain-text passwords

### Phase 3: Add Real Audio Processing

- Request and manage microphone permission
- Capture microphone input
- Add speech-to-text
- Detect supported Filipino and Bisaya filler words
- Calculate speaking pace from recognized words and time

### Phase 4: Add Body-Language Analysis

- Add face and upper-body landmark detection
- Measure camera-facing attention
- Define and validate posture rules
- Keep processing on-device where possible for privacy

### Phase 5: Validate Scoring

- Define transparent scoring weights
- Test scores with teachers and students
- Separate objective measurements from coaching recommendations
- Explain each score to the user
- Avoid presenting prototype estimates as medical or psychological judgments

### Phase 6: Production Readiness

- Add secure authentication
- Add privacy consent and retention controls
- Encrypt sensitive local data
- Add crash reporting and production logging
- Test on multiple Android phone cameras and screen sizes
- Conduct accessibility, performance, and security testing

## 17. Current System Classification

SpeakSync should currently be presented as:

> A functional Flutter front-end prototype with a real mobile camera preview,
> simulated rehearsal intelligence, prototype scoring, and an interactive
> progress-history experience.

It should not yet be presented as a complete AI analysis system, a secure
authentication system, or a production-ready recording platform.
