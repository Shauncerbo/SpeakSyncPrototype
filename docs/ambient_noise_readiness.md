# Ambient noise readiness check

## Flow

Practice Setup -> Device Check -> Camera Preview and noise check -> I'm Ready ->
3-second countdown -> Rehearsal. Device Check's Camera Preview button opens the
preview; it does not start rehearsal recording or the timer.

The existing camera readiness preview automatically refreshes the ambient check
after camera initialization/permission handling. Each sample lasts 2.5 seconds,
with a 0.5-second gap before the next sample (about 3 seconds per update, plus
native microphone startup/shutdown time). Stay silent while the room is sampled.
The UI shows Checking initially, then retains the latest Quiet, Moderate, Noisy,
or Unavailable result while refreshing. There is no Check again button. Moderate
shows a small warning; Noisy asks whether to go back or Continue anyway.
Unavailable never blocks rehearsal and retries automatically after five seconds.
Permission is requested at most once per preview; retries only read its status.

Pressing I'm Ready cancels any remaining noise sampling and waits for microphone
release before the existing three-second countdown. Only then does normal
rehearsal recording/timing begin. Backgrounding, leaving the preview, and opening
Device Check also stop the check. Returning to the foreground/preview, cancelling
the countdown, or choosing Go back from the noise warning resumes automatic checks.
It does not run during the countdown, rehearsal, or rehearsal restart.
The sample is not saved, uploaded, transcribed, or included in rehearsal duration.

## Calculation and configurable prototype thresholds

`lib/services/ambient_noise_service.dart` contains `AmbientNoiseConfig`, the PCM
accumulator, and the microphone service. No new dependency or Hive field is needed.

- Request mono PCM16 little-endian at 16,000 samples/second for 2.5 seconds.
- Normalize each signed sample: `x = sample / 32768`.
- Aggregate energy across all received samples: `RMS = sqrt(sum(x*x) / N)`.
- Compute only running energy/count; do not retain audio buffers.
- No samples, a broken stream, or fewer than 8,000 samples means Unavailable,
  not Quiet. Cancelled checks also return Unavailable.

| Classification | Normalized RMS |
| --- | --- |
| Quiet | below 0.01 |
| Moderate | 0.01 up to, but not including, 0.05 |
| Noisy | 0.05 or above |

These are prototype thresholds, not scientifically validated values or calibrated
sound-pressure measurements. They must be calibrated on real devices. The requested
auto-gain, echo cancellation, and noise suppression settings are disabled for this
sample, but hardware/OS processing may still affect input.

## Android manual test

1. Open Practice Setup, complete it, and reach the camera readiness preview.
   Allow microphone access. Remain silent until the check finishes.
2. Quiet: use a quiet room with the phone stationary. Expect Quiet if RMS is below
   0.01. Verify no rehearsal timer is running yet.
3. Moderate: use a fan or low-volume background conversation/music at a safe
   volume. Wait for automatic refresh and adjust distance/volume until
   Moderate appears. I'm Ready should proceed without a confirmation dialog.
4. Noisy: increase background sound moderately or move nearer the source; do not
   use dangerously loud sound. Wait for automatic refresh. With Noisy, I'm Ready should offer
   Go back or Continue anyway. Test both choices.
5. Press I'm Ready while Checking. Sampling must stop before 3, 2, 1. The timer
   must begin at the full selected duration, excluding all preparation/check time.
6. Deny microphone permission, or disable microphone access in Android settings.
   Check for Unavailable (some devices instead return silent samples). Confirm
   the check itself doesn't trap the student or repeatedly open permission dialogs.
   Re-enable access and return to the app; checking should recover automatically.
7. Leave/back out or background the app while Checking; verify microphone usage
   stops. Return and verify automatic checks resume.
8. Finish a short normal rehearsal and confirm the existing transcript, WPM,
   filler counts, script comparison, and saved report still work. No ambient-noise
   result should be added to the report.

Return to a quiet room and wait for Quiet to appear again, without tapping a button.
Background sound examples cannot guarantee a classification across phones. Test
the numeric thresholds with synthetic samples in automated tests; calibrate the
real-world labels on representative Android hardware.

## Limitations

- Microphone sensitivity/gain, audio routing, Bluetooth/headsets, OS processing,
  microphone privacy switches, and other recording apps can change or prevent input.
- A muted microphone returning zeros cannot be distinguished from genuine digital
  silence by RMS alone. Missing input is handled separately.
- Speaking during the check increases RMS: this is not VAD or speaker recognition.
- Measurements are short snapshots refreshed only on the readiness preview.
  There is no noise monitoring during actual rehearsal.
- Real Android/iOS microphone behavior needs physical-device validation; widget
  tests exercise fake input and permission responses, not native capture.

## Files changed for this feature

- `lib/services/ambient_noise_service.dart` (new)
- `lib/screens/practice_flow.dart`
- `test/ambient_noise_service_test.dart` (new)
- `test/rehearsal_readiness_test.dart`
- `docs/ambient_noise_readiness.md` (new)

Existing Groq, WPM, filler, script-comparison, Hive, and report logic is unchanged.

## Validation

- `dart format .`: completed.
- `flutter analyze`: no issues found.
- `flutter test`: 422 passed, 1 configuration-dependent test skipped.
- Separate readiness run with a placeholder Groq configuration and fake recorder:
  all 14 passed, including the normally skipped startup-cancellation case.
- Tests cover automatic level changes, error recovery without repeated permission
  prompts, stopping for countdown/rehearsal, background/resume, and countdown
  cancellation. The full suite includes 324 responsive layout cases.
