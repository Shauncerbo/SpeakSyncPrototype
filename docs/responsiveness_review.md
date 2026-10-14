# Responsive layout review

## Test coverage

Flutter widget tests simulate these logical-pixel sizes in portrait and landscape:

| Device class | Portrait size |
| --- | --- |
| Small Android | 320 × 568 |
| Large Android | 412 × 915 |
| Android tablet | 800 × 1280 |
| Small iPhone | 375 × 667 |
| iPhone | 390 × 844 |
| iPad | 768 × 1024 |
| iPad Pro | 1024 × 1366 |

Additional small-Android/iPad cases use 150% text scaling. Android/iOS theme behavior and representative safe-area padding are included. These are simulated layout checks, not physical-device tests.

324 cases cover splash, onboarding, login, registration, keyboard-open forms, Home, Progress, Settings, Privacy dialog, Practice Setup, Device Check, preview, active rehearsal, analysis, Performance Report, Session Details, and About.

Camera assertions check frame aspect ratio, maximum width, landscape height, microphone-indicator alignment, and a minimum 48-pixel microphone button height. Widget tests use the preview fallback, not a native camera stream.

## Findings and fixes

- Splash/onboarding/analysis overflowed short phones and landscape. Content now scrolls when needed and stays centered when it fits.
- Home/rehearsal fixed-aspect-ratio grids overflowed. Equal-width cards now grow with their contents and reduce column count on narrow screens or with larger text.
- Progress summary cards adapt instead of squeezing three columns onto small phones.
- Login/registration forms now have a centered 560-pixel maximum width, safe-area padding, and keyboard-safe scrolling.
- Onboarding footer buttons now share the page's maximum width on tablets.
- Branding scales within its available width; section-header actions can move onto another line with larger text.
- Device Check status labels wrap, moving below titles when space is limited.
- Settings alert-frequency dropdown/helper text fit narrow screens. The Privacy dialog title wraps and its content scrolls.
- Rehearsal metric labels/descriptions wrap. Countdown/transcription overlays scroll on short displays. Microphone/camera buttons have 48-pixel minimum visual targets.
- Camera frame uses 9:16 portrait or 16:9 landscape with a height-aware landscape width limit. Existing sensor-orientation logic is retained. `BoxFit.contain` avoids stretching/cropping; letterboxing is intentional. Overlays align with the frame instead of the full tablet page width.
- WPM/filler value columns flex within report cards, resolving large-text overflow in Performance Report and Session Details.

## Files changed for this review

- `lib/login.dart`
- `lib/register.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/progress_screens.dart`
- `lib/screens/practice_flow.dart`
- `lib/screens/splash_onboarding.dart`
- `lib/screens/settings_screens.dart`
- `lib/widgets/common_widgets.dart`
- `lib/widgets/speaking_pace_card.dart`
- `lib/widgets/filler_frequency_card.dart`
- `test/responsive_layout_test.dart`
- `docs/responsiveness_review.md`

Pre-existing script-comparison changes were retained. No database, scoring, transcription, networking, or rehearsal-state behavior was changed for this review.

## Validation results

- `flutter analyze`: no issues found.
- `flutter test`: 394 passed, 1 configuration-dependent test skipped.
- Separate readiness run with a placeholder configuration and fake recorder: both tests passed, including the normally skipped case.
- The full suite includes all 324 responsive layout cases.

## Remaining device checks

- Native camera sensor rotation/mirroring and permission dialogs require real Android/iOS tests.
- Actual notches, gesture bars, keyboards, and split-screen windows vary from the representative automated insets.
- Native iOS/iPadOS builds were not run on this Windows machine.
- Compact session-title previews intentionally retain ellipsis; full titles remain available in Session Details.
- Camera letterboxing is expected when sensor and frame ratios differ.

Re-run with `flutter analyze`, `flutter test`, or `flutter test test/responsive_layout_test.dart`.
