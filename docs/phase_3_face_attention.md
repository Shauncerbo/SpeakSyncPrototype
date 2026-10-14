# Phase 3 — On-device estimated camera-facing attention

Implementation date: October 10, 2026. This supplements the historical
`SPEAKSYNC_SYSTEM_AUDIT.md` and the Phase 2A nullable-results report.

## Scope and meaning

SpeakSync now integrates Android MediaPipe Face Landmarker into the existing
camera stream. It estimates **head orientation toward the camera**, not actual
eye contact, concentration, confidence, identity, or audience engagement.
No overall performance formula, authentication change, new cloud API, or
replacement simulated attention percentage was introduced.

The native model/bridge is implemented and can be compiled into an Android APK.
Automated tests exercise deterministic Dart logic, channel contracts with
mocked results, UI and storage. They do **not** establish native inference
accuracy or correct head-angle interpretation on physical cameras.

## Shared camera architecture

The existing Flutter `CameraController` preview and single YUV420 image stream
are retained. `PoseFrameGate` limits accepted frames to at most two per second,
with one Dart request in flight. One method-channel frame message feeds both
tasks; there is no second camera stream or duplicate plane serialization.

`MainActivity.configureMonitoring` loads Face only when its toggle is enabled.
`initializeLandmarker` loads Pose only when body monitoring requires it. Face
uses one-face VIDEO tracking mode, transformation-matrix output enabled and
blendshape output disabled. Detection, presence and tracking confidence minima
are provisionally 0.6. Pose keeps its existing LIVE_STREAM mode and thresholds.

`analyzeFrame` downsamples and rotates the camera image once using the existing
384-pixel maximum dimension. Face `detectForVideo` runs synchronously on the
single native background executor, followed by existing asynchronous Pose
inference. The result combines Pose data with Face data. Face-only monitoring
works when body monitoring is off. Face initialization/inference failures yield
unavailable face data without intentionally discarding successful pose data.
Native in-flight gating skips requests rather than building an inference queue.

Only a face-derived transformation matrix and five actual landmark coordinates
(nose 1, outer eyes 33/263, chin 152, forehead 10) cross the bridge. They are
transient; neither face images nor landmarks are persisted to Hive. Converted
MPImages are released after completion, and the intermediate unrotated bitmap
is recycled when rotation created another bitmap. Native teardown is serialized
with worker inference. Camera frames are not uploaded or saved as raw video by
the normal rehearsal flow.

The native callback watchdog is scheduled at two seconds on the worker queue;
it cannot preempt a hung synchronous task. Dart bounds each frame request at
three seconds, model configuration/initialization at five seconds, and close
at three seconds. Independently, a 500ms Dart watchdog clears stale face state.
Results delayed beyond the valid sample gap are unavailable. A truly hung
native worker may prevent visual recovery until activity/app restart; it must
not invent measurements or block final audio analysis indefinitely.

This is an extension of the existing camera architecture, not a replacement.
Combined inference increases workload and sample latency; hardware benchmarking
is still required. Existing debug timing totals now include Face + Pose work,
even where their pre-existing diagnostic class/log is still named Pose.

## Head orientation and classification

`HeadOrientationAnalyzer.analyze` validates the returned matrix/landmarks:
five finite normalized points in-frame, non-degenerate eye/face spans, a finite
16-element matrix, non-degenerate approximately orthogonal rotation columns,
and a valid homogeneous scale. Invalid data returns unavailable, not away.

The [MediaPipe Java API](https://ai.google.dev/edge/api/mediapipe/java/com/google/mediapipe/tasks/vision/facelandmarker/FaceLandmarkerResult)
defines a column-major canonical-to-detected face matrix. The third rotation
column supplies the estimated head-forward normal `n = (m[8], m[9], m[10])`.
SpeakSync uses its azimuth/elevation rather than pupil gaze:

```text
yaw   = atan2(n.x, n.z) × 180 / π
pitch = atan2(-n.y, sqrt(n.x² + n.z²)) × 180 / π
```

Frames are analyzed in the rotated, unmirrored sensor coordinate system.
Preview mirroring does not alter these absolute-angle comparisons. Correct
axis/sign interpretation, portrait/landscape handling, and front/rear camera
behavior require real-device validation. Head roll is not independently scored.

`FaceAttentionThresholds` is the central Dart configuration; these are
**provisional prototype thresholds, not scientifically validated limits**:

| Rule | Default |
| --- | --- |
| Facing Camera | Smoothed absolute yaw ≤25° AND absolute pitch ≤20°. |
| Looking Away | Either limit exceeded with valid orientation data. |
| Recovery from Looking Away | Smoothed yaw ≤20° AND pitch ≤15°. |
| Smoothing | Latest 3 valid observations; average absolute yaw and pitch. |
| Warm-up | 3 valid consecutive observations before a live classification. |
| Maximum valid sample gap | 1,200ms; missing/nonmonotonic/stale data breaks continuity. |
| Minimum final valid analysis | 3 seconds. |
| Looking-away warning | State persists for 3 seconds with adjacent valid samples. |
| Warning recovery | Facing state persists for 2 seconds. |
| Missing data | Immediately Unavailable; clear away warning and smoothing. |

The implementation tolerates floating-point roundoff at inclusive angle
boundaries. The native confidence minima and .02 normalized eye/face-span
guards also require calibration. At extreme turns the model may stop detecting
a face, which is unavailable rather than a failed/away sample.

## Time measurement

`FaceAttentionTracker.addFrame` integrates intervals only between adjacent
valid, stabilized observations no farther apart than the maximum gap. Each
interval is assigned the previous stable classification. Warm-up, missing
faces, camera-off/background periods, late results and interruptions do not
contribute to either denominator or numerator. Missing callbacks expire through
the watchdog; accumulated genuine valid time is preserved.

```text
estimated camera-facing percentage =
    accumulated Facing Camera time / accumulated valid classified face time × 100
```

It does not divide by total rehearsal duration. A sufficiently analyzed
rehearsal that is always Looking Away can genuinely measure 0%; insufficient
data remains null. A high percentage can coexist with low valid coverage. The
current UI does not grade coverage or claim a full-session attention score.
Future reporting should expose valid coverage alongside the estimate so users
can judge representativeness; the denominator is already stored.

`interrupt` clears continuity/live state but preserves accumulated measured
time. `reset` clears all durations, smoothing and live state for restart/new
rehearsal. Warning reset clears previous persistence/recovery timers.

## Student flow and toggles

Settings and Practice Setup camera-facing toggles are re-enabled using their
existing Hive preference/setup fields. Readiness/countdown timing is unchanged;
visual inference starts only after rehearsal starts, not during preparation.

The existing rehearsal metric now shows **Facing Camera**, **Looking Away**, or
**Unavailable** while monitoring is enabled; OFF displays Off. The optional
persistent, non-blocking warning says the head appears turned away. It requires
both attention monitoring and Live Feedback. Live Feedback OFF hides this
warning but does not stop enabled local analysis or its final result. It does
not re-enable live Whisper chunks/filler/pace requests when Live Feedback is off.

Report and Session Details show the valid-time percentage only with sufficient
provenance. Coaching may suggest facing the camera based on measured samples,
explicitly excluding an eye-contact claim. Overall rings/rankings remain Not
scored/unavailable. WPM, fillers, posture, framing and script comparison are
preserved rather than combined into a new formula.

## Hive compatibility and provenance

All existing type IDs and indexes are unchanged. `PerformanceReport` remains
type ID **5**. Existing nullable camera fields are used:

| Index | Field | Stored meaning |
| --- | --- | --- |
| 8 | cameraFacingSeconds | Actual accumulated facing duration truncated to whole seconds, only when sufficient valid data exists. |
| 9 | cameraScore | Rounded valid-time percentage; despite the legacy name, not an educational score. |
| 26 (new, optional) | validFaceAnalysisMilliseconds | Valid face-analysis denominator/provenance; null for legacy records or disabled monitoring. |

Percentage calculation uses precise tracked durations before integer storage;
it is not recomputed from truncated facing seconds. Zero coverage may be saved
when monitoring was requested but no valid samples arrived; its percentage and
facing seconds remain null. Persistence/UI require at least 3,000ms valid
coverage before accepting a head-facing result. Custom thresholds below the
storage minimum cannot establish persisted availability; changing this contract
requires coordinated updates to tracker/model/repository.

The regenerated adapter writes 27 fields and reads absent index 26 as null.
Old numeric/nullable reports are not automatically rewritten or deleted. Old
82% or other numbers lacking new coverage remain legacy values, never genuine
head measurements. Repository validation requires sufficient face coverage,
paired percentage/time, valid ranges, and facing time no longer than valid
coverage. OFF excludes face data/coaching even if supplied by another caller.

Compatibility tests exercise real old numeric and Phase 2A nullable bytes.
A Phase 2A nullable-reader fixture can read new records while ignoring index
26; reopening with the new adapter retains the field. An older app that
**writes** a read record back can drop fields it does not know; downgrade writes
are not supported or performed. Pre-nullable APKs still cannot safely read
nullable score fields. Back up local data before upgrade/downgrade experiments;
do not uninstall or reset data as an installation workaround.

## Model and official references

- Existing Android dependency: `com.google.mediapipe:tasks-vision:0.10.29`;
  no new Flutter package or service credential.
- Bundled `android/app/src/main/assets/face_landmarker.task`: Google version 1,
  3,758,596 bytes. Downloaded from the official MediaPipe model distribution.
- SHA-256: `64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff`.
- [Official model/overview](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker)
  and [Android guide](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker/android).
- [Pinned model download](https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task).

These references support API/model choices, not the scientific validity of
SpeakSync's thresholds. Review model/distribution notices before public release.

## Files changed

| File | Role |
| --- | --- |
| `android/app/src/main/kotlin/com/speaksync/speaksync_prototype/MainActivity.kt` | Shared conversion, optional Face model, worker inference, combined response, cleanup/watchdog. |
| `android/app/src/main/assets/face_landmarker.task` (new) | Bundled real on-device model. |
| `lib/services/face_attention.dart` (new) | Thresholds, matrix validation, orientation, smoothing/time integration, warning state. |
| `lib/services/posture_landmarker_service.dart` | Shared monitoring capability, frame flags and independent face-result parsing. |
| `lib/models/practice_session.dart` | Face coverage/time, provenance-gated estimate, measured coaching. |
| `lib/models/performance_report.dart` | Optional additive field 26. |
| `lib/models/performance_report.g.dart` | Regenerated compatible adapter. |
| `lib/storage/hive_repository.dart` | Genuine camera measurements, validation/provenance, toggle handling, history mapping. |
| `lib/screens/practice_flow.dart` | Setup toggle, shared inference lifecycle, watchdog, live status/warning, restart and report. |
| `lib/screens/settings_screens.dart` | Existing toggle enabled; truthful local Face privacy/about wording. |
| `lib/screens/progress_screens.dart` | Estimated head-facing history label/disclaimer; no overall formula. |
| `test/face_attention_test.dart` (new) | Orientation boundaries, missing/invalid data, smoothing, valid-time math, warnings/restart/OFF. |
| `test/shared_camera_landmarker_test.dart` (new) | One shared request, Face-only mode, disabled/malformed face isolation. |
| `test/nullable_performance_storage_test.dart` | Real measurement/null distinctions, OFF, old bytes/readers and validation. |
| `test/scoring_integrity_test.dart` | Legacy exclusion and genuine Face display in report/history. |
| `test/widget_test.dart` | Enabled optional toggle and updated local-privacy text. |
| `test/rehearsal_readiness_test.dart` | Missing native camera analysis shows Unavailable, not simulated values. |
| `test/hive_repository_test.dart` | Preserve selected attention monitoring without fabricating its result. |
| `docs/phase_3_face_attention.md` (new) | Implementation, compatibility and physical-device handoff. |
| `SPEAKSYNC_SYSTEM_AUDIT.md` | Historical-baseline notice linking to current phase reports. |

## Verification

| Check | Final observed result |
| --- | --- |
| `dart format` on all 16 changed/new Dart files | Passed; final run reported 0 further formatting changes. |
| `flutter analyze --no-pub` | Passed: no issues found. |
| `flutter test --no-pub --reporter expanded` | Passed: 542 tests passed, 2 skipped by existing configuration gates. |
| Two gated readiness/recording tests, separately with a dummy define and mocks | Passed: 2 tests passed; no real network/API requests. |
| `flutter build apk --debug --dart-define-from-file=.env.json --no-pub` | Passed: final Gradle build reported 43.4 seconds. Credentials redacted. |
| APK ZIP inspection | Both Pose and Face task bundles present; bundled Face SHA-256 matches the pinned downloaded model. |

Final APK: `build/app/outputs/flutter-apk/app-debug.apk`, 223,430,778 bytes,
written October 10, 2026 at 19:11:42 workspace-local time. This verifies
compilation and packaging, not successful native camera inference on a phone.

Tests added/extended cover yaw/pitch boundaries, nonfinite/degenerate/missing
landmarks, column-major extraction, smoothing/hysteresis, valid-only mixed-time
percentage, genuine measured zero, stale/missing intervals, persistent warnings,
recovery, disabled monitoring/alerts, restart, one shared frame request,
Face-only mode, malformed/disabled Face isolation, provenance validation, old
numeric and nullable wire formats, unchanged historical bytes, and report/history
display. Existing speech, pose, framing, storage, readiness and responsive
regressions passed in the full suite.

During implementation, checks caught a Dart interface-promotion error, mechanical
lint findings, floating-point boundary rounding, and stale/over-broad test
assertions for the former planned attention UI. These were corrected; no errors
remain in the final commands above. Deliberate adapter replacement warnings in
the compatibility fixtures are test-only. The pre-existing Hive generator warning
about its analyzer dependency versus the newer Dart SDK remains; generation
succeeded without a dependency upgrade.

Implementation and automated validation are complete. Physical-device accuracy,
matrix-axis calibration, upgrade testing on actual student data, native lifecycle
stress testing and Pose+Face performance benchmarks remain required. No such
results are claimed here, and no further development phase has been started.

## Physical Android validation — required before accuracy claims

1. Back up existing local data; install the updated debug APK without uninstall
   or Reset Prototype Data. Verify older history still exists and old attention
   percentages remain unavailable.
2. Enable camera-facing monitoring. Start from device check → preview → I'm
   Ready → countdown. Confirm no analysis time from preparation is included.
3. Face forward for at least 10 seconds: expect stable Facing Camera and an
   available final head-facing fraction after enough valid analysis.
4. Turn left/right around 15°, 25°, 35° and then tilt up/down around the pitch
   limits, holding each position. Check labels, three-second away persistence
   and two-second recovery. Brief turns must not repeatedly flash warnings.
5. Cover/leave the camera view, disable camera, background/lock/resume the app,
   and interrupt permission/camera access. Expect Unavailable/cleared warning,
   no missing-time penalty, and safe recovery or clear unavailability.
6. Disable attention monitoring: no Face inference/result/warning should occur.
   Disable body monitoring only: Face should still work. Disable Live Feedback:
   no head-direction warnings or live cloud chunks, but enabled local analysis
   and final reports should remain available.
7. Restart mid-rehearsal and compare a fresh attempt: old Face duration, label,
   warning and rolling window must not carry over.
8. Check report → save → force-close → history: percentage/time/coverage should
   survive, genuine measured zero must differ from unavailable, and final WPM,
   fillers/script comparison must still use the complete final transcript.
9. Repeat offline, on portrait/landscape and front/rear cameras, with glasses,
   varied lighting, framing distance and different phones/users. Extreme profile,
   occlusion or tiny faces may legitimately be unavailable. One selected face
   does not prove the face belongs to the rehearsing student; avoid bystanders.
10. Compare Pose-only versus Pose+Face latency, processed FPS, preview smoothness,
    audio quality, memory/thermal behavior and battery over a full rehearsal.
    Calibrate thresholds and validate matrix-axis mapping using known head
    positions before claiming accuracy. Weaker devices may lose valid samples
    rather than produce a fabricated percentage.

No physical phone, native model accuracy, API request, or benchmark was verified
by the automated checks described in this report.
