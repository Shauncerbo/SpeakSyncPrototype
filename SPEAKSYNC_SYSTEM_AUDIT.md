# SpeakSync System Audit

**Audit date:** October 10, 2026 (Asia/Manila)  
**Workspace:** `C:\SpeakSync_Flutter`  
**Source baseline:** branch `main`, HEAD `bc1fad1`, including the existing modified and untracked working-tree files. This is an audit of the local implementation, not just the committed repository.  
**Scope:** Flutter/Dart source, Android native implementation, dependency/build configuration, Hive models/adapters/repository, navigation, screens, services, widgets, automated tests, and existing documentation. Only this Markdown file was created; application source was not repaired, formatted, refactored, or generated.

## Reading this audit

> Historical baseline notice: this audit describes the source before Phase 1,
> Phase 2A and Phase 3 updates. Its original findings below are retained as audit
> evidence, not claims about the latest source. Phase 1 repaired the filler
> compilation defect; Phase 2A removed prototype score presentation and adopted
> nullable results. Phase 3 adds Android Face Landmarker/head-direction estimates.
> See [Phase 2A results](docs/phase_2a_nullable_results.md) and
> [Phase 3 implementation and verification](docs/phase_3_face_attention.md) for
> the updated behavior, actual check results and physical-device limitations.
>
> Phase 4A replaces broad/fixed post-session recommendations with final
> measurement-based coaching and persists valid camera-framing durations.
> See [Phase 4A implementation](docs/phase_4a_measurement_coaching.md).
> Phase 4B and validated scoring formulas have not been implemented.

The project contains substantial real analysis code, but the **current source does not pass compilation/static analysis**. `lib/services/filler_analysis.dart` has a malformed conditional around lines 21–23. This prevents dependent application code and several test suites from compiling. Feature descriptions below explain the actual wired implementation and its limitations; they are not a claim that a fresh build currently runs successfully.

Status vocabulary:

| Status | Meaning in this report |
| --- | --- |
| Implemented | Concrete logic exists and is connected to the current application flow. Device accuracy or production suitability is a separate question. |
| Partial | Some real logic exists, but integration, correctness, lifecycle behavior, or requirements remain incomplete. |
| Simulated/placeholder | Displayed results originate from fixed values or demo state rather than the corresponding real measurement. |
| Unused | Code/model field exists without an active user-flow consumer or reachable action. |
| Planned/missing | No implementation or integration was found for the requested capability. |
| Broken | A current source defect demonstrably prevents compilation or the expected behavior. |
| Verification needed | Source or tests provide evidence, but native hardware, live API behavior, calibration, or deployment was not verified. |

Evidence distinguishes **confirmed source behavior**, **observed validation results**, and **potential defects inferred from control flow**. Existing README/documents and previous successful APKs are not treated as proof of current operation.

## 1. System Overview

SpeakSync is a public-speaking rehearsal application intended for Senior High School students. It supports three speech types, local reference-document extraction, camera preparation, microphone recording, cloud transcription, transcript-based pace/filler analysis, on-device upper-body posture analysis, saved reports, and local progress history. It has no teacher/admin portal or cloud account/database integration in the inspected source.

The actual implementation is a **hybrid prototype**: speech transcription uses Groq Cloud, posture uses Android MediaPipe Pose, and several measurements are deterministic Dart rules. Camera-facing attention and parts of scoring/coaching still use prototype values. Authentication is a development bypass rather than an operational student account system.

### Architecture

```text
main.dart -> HiveRepository.initializeStorage -> SpeakSyncApp
                    |
                    v
           AppState / AppStateScope
                    |
         Navigator + MaterialPageRoute
                    |
       Home / Progress / Settings (MainShell)
                    |
PracticeSetup -> DeviceCheck -> RehearsalScreen preview/readiness
                    |
              countdown -> rehearsal
                    |
       +------------+-----------------------+
       |                                    |
one microphone capture                existing camera stream
       |                                    |
full audio + optional 10s chunks       Android MethodChannel
       |                                    |
Groq Whisper                         MediaPipe Pose Landmarker
       |                                    |
transcript -> WPM/fillers/LCS          posture + framing + overlay
       +----------------+-------------------+
                        |
           PracticeSession (in-memory report)
                        |
              explicit Save to Progress
                        |
        normalized Hive boxes -> history aggregates
```

State management is Flutter `ChangeNotifier` and an `InheritedNotifier` (`AppStateScope`), not a separate Provider/Riverpod/BLoC dependency. Services handle transcription, recording, text extraction, comparison, connectivity, noise, pose geometry, and screen wake-lock. Native Android Kotlin handles Pose Landmarker initialization, camera conversion, and inference.

### Technologies and environment

`pubspec.yaml` declares Dart `^3.11.3`, Material 3, and application version `1.0.0+1`. Resolved packages in `pubspec.lock` include:

| Technology | Resolved/configured version | Actual role |
| --- | --- | --- |
| camera | 0.11.4 | Native camera preview and image stream |
| permission_handler | 11.4.0 | Runtime camera/ambient microphone permissions |
| record | 6.2.1 | AAC recording, PCM streams, input amplitude |
| http | 1.6.0 | Groq multipart upload |
| Hive / hive_flutter | 2.2.3 / 1.1.0 | Local typed boxes |
| file_picker | 12.0.0 | PDF/DOCX/TXT selection |
| archive / xml | 4.1.0 / 7.0.1 | DOCX ZIP/XML extraction |
| pdfrx / pdfrx_engine | 2.4.7 / 0.4.5 | Local PDF text-layer extraction |
| internet_connection_checker_plus | 3.1.1 | Internet reachability and status events |
| path_provider | 2.1.6 | Temporary audio directory |
| wakelock_plus | 1.6.1 (pinned) | Keep display awake during rehearsal |
| MediaPipe Tasks Vision | 0.10.29 | Native Android Pose Landmarker |
| Android Gradle plugin / Kotlin | 8.11.1 / 2.2.20 | Android build |
| Gradle / Java target | 8.14 / 17 | Wrapper and JVM compilation settings |

The supported native target evidenced by the project is **Android**. `android/app/build.gradle.kts` delegates compile/min/target SDKs to Flutter, rather than fixing numbers in the app file. The existing cached debug merged manifest records **minimum API 24 and target API 36**; these describe that prior build, not a newly built October artifact. Recheck effective SDK requirements after future dependency/toolchain changes. API 31 Android hardware falls within that recorded range, but this audit did not connect a phone.

An Android-only guard exists in `MethodChannelPostureLandmarker.initialize()`. No `ios/`, macOS, Windows, or Linux runner directories were found. A `web/` scaffold exists, but production web compatibility is not established: key services use `dart:io`, file-backed audio, `Platform`, and an Android native channel. Simulated iPhone/iPad layout tests do not establish iOS/iPadOS build support.

## 2. Project Structure

| Path | Responsibility / important classes |
| --- | --- |
| `lib/main.dart` | Initializes Flutter and Hive; falls back to an in-memory `AppState` on storage initialization failure. |
| `lib/app.dart` | `SpeakSyncApp`, `AppTimingScope`, MaterialApp, named `/home` and `/register` routes, global `ConnectionNotice`. |
| `lib/core/app_theme.dart` | Material 3 theme, colors, common button/card styling. |
| `lib/core/app_config.dart` | `AppConfig.groqApiKey = String.fromEnvironment('GROQ_API_KEY')`; checks non-empty compile-time configuration. |
| `lib/login.dart`, `lib/register.dart`, `lib/auth_service.dart` | Development login bypass and in-memory mock registration. Not linked to an active Hive user. |
| `lib/state/app_state.dart` | `AppState` coordinates preferences, saved session aggregates, current setup/report, loading/error state; `AppStateScope` exposes it. |
| `lib/data/dummy_data.dart` | Four demonstration rehearsals, synthetic scores/transcripts, shared demo preferences. |
| `lib/models/` | Six persistent Hive types, generated `.g.dart` adapters, two temporary/UI models. |
| `lib/storage/hive_box_names.dart` | Actual box names, migration/seeding flags, demo-user ID. |
| `lib/storage/hive_repository.dart` | `HiveRepository`, relationship validation, save/reload mappings, duplicate guard, rollback, cascade deletion, migration and seeding. |
| `lib/screens/splash_onboarding.dart` | Timed splash; three-page onboarding; navigation to login. |
| `lib/screens/main_shell.dart` | Home/Progress/Settings tabs using `IndexedStack`; loading/storage error UI; quick practice action. |
| `lib/screens/home_screen.dart` | Latest score, totals, improvement, goal, recent session, rule-based coaching. |
| `lib/screens/practice_flow.dart` | Setup, device checks, camera readiness, countdown, rehearsal/audio/pose orchestration, report generation, report saving. This file contains most flow coordination. |
| `lib/screens/progress_screens.dart` | Score trend/rankings/history, improvement and weakest-area summaries, reopened session details. |
| `lib/screens/settings_screens.dart` | Persisted monitoring/live preferences, alert-frequency selection, privacy/help/about, data clear/restore, navigation-only logout. |
| `lib/screens/dashboard.dart` | Legacy dashboard not referenced by the current app navigation; its `/login` named route is not registered. |
| `lib/services/groq_transcription_service.dart` | HTTP Whisper service and typed failures. |
| `lib/services/rehearsal_audio_recorder.dart`, `wav_audio.dart` | One capture; full AAC or PCM/WAV recording; optional chunks; amplitude; cleanup. |
| `lib/services/live_filler_feedback_service.dart` | Shared chunk transcription, bounded processing, duplicate suppression, live filler and rolling pace callbacks. |
| `lib/services/filler_analysis.dart`, `speaking_pace.dart` | Transcript token detection and rate calculations. Filler service is currently syntactically broken. |
| `lib/services/speech_document_service.dart`, `script_comparison_service.dart` | Local document extraction and bounded word-order comparison. |
| `lib/services/ambient_noise_service.dart` | Configurable RMS readiness assessment and native microphone lifecycle. |
| `lib/services/posture_landmarker_service.dart` | Android channel interface, pose result parsing, orientation helper, monitoring gate. |
| `lib/services/posture_analysis.dart` | Shoulder/torso posture rules, majority smoothing, valid-duration percentage. |
| `lib/services/posture_performance.dart` | 2 FPS request gate, one active frame, diagnostics, size bounds. |
| `lib/services/posture_warning_controller.dart` | Persistent warning/recovery timers. |
| `lib/services/camera_framing.dart` | Normalized body-scale estimate and hysteresis. |
| `lib/services/internet_connectivity_service.dart`, `screen_awake_service.dart` | Reachability monitoring and wake-lock abstraction. |
| `lib/widgets/common_widgets.dart` | Branding, responsive page/grid layout, metrics, session cards, script-comparison cards, CustomPainter score/chart. |
| `lib/widgets/connection_notice.dart` | Global auto-dismiss online/offline message above navigation. |
| `lib/widgets/speaking_pace_card.dart`, `filler_frequency_card.dart` | Real transcript-rate display and unavailable states. |
| `lib/widgets/pose_landmark_overlay.dart` | Four-landmark debug skeleton, aspect/mirroring transform, debug toggle. |
| `android/app/src/main/kotlin/com/speaksync/speaksync_prototype/MainActivity.kt` | Native MediaPipe pipeline, single executor, LIVE_STREAM callbacks, YUV downsampling. |
| `android/app/src/main/assets/pose_landmarker_lite.task` | Bundled model file exists (5,777,746 bytes); model accuracy/provenance not independently verified. |
| `android/` | Manifests, Kotlin/Gradle, launch resources. |
| `test/` | 20 automated test files; unit/widget coverage, fake recorders/connectivity/API, local extraction tests. |
| `docs/`, `README.md` | Earlier design/implementation guides; some are substantially outdated. |
| `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml` | Dependencies, resolved versions, Flutter lint rules. |
| `.env.json`, `.env.json.example`, `.gitignore` | Local compile-time Groq config, tracked example, ignore rules. Secret values are intentionally omitted. |
| `build/`, `.dart_tool/`, `.dart-appdata/` | Generated build/tool state; not source evidence of current success. `.dart-appdata/` appears untracked and should be excluded from release commits. |

### Actual persistent schema

The current type IDs are **0 through 5**. Earlier diagram proposals using different IDs should not override the adapters/repository.

| Hive box | Type / type ID | Key | Important contents |
| --- | --- | --- | --- |
| `users` | `User` / 0 | `userId` | Names, email, optional school, creation date; no password field. |
| `appPreferences` | `AppPreferences` / 1 | `userId` | Monitoring/live flags, language/duration defaults, alert frequency. |
| `speechProfiles` | `SpeechProfile` / 2 | `speechProfileId` | Prepared/Persuasive script and document name, speech metadata. |
| `rehearsalSessions` | `RehearsalSession` / 3 | `sessionId` | User/profile references, speech snapshots, duration/date, monitoring flags. |
| `fillerWordLogs` | `FillerWordLog` / 4 | `logId` | Canonical filler, count, legacy times, normalized-transcript offsets. |
| `performanceReports` | `PerformanceReport` / 5 | `reportId` | Transcript, real word/WPM/count data, mixed real/prototype scores, comparison results, posture duration. |
| `applicationMetadata` | dynamic | metadata key | One-time demo seeding and legacy-user migration flags. |

`PracticeSettings` is temporary setup state. `PracticeSession` is the UI aggregate reconstructed from a rehearsal record plus its report; it is not a Hive type. `User` retains fields 6 and 7 for school/date and leaves removed password index 5 unused. `PerformanceReport` contains fields 0–25; new comparison fields and `validPostureSeconds` are nullable or defaulted in its adapter. `FillerWordLog.transcriptOffsets` is appended at field 5 with an empty-list legacy default. Do not renumber existing persisted indexes without a deliberate migration.

## 3. Complete Feature Inventory

### 3.1 Launch, onboarding, authentication, and profiles

**Launch/onboarding: implemented UI.** `SplashScreen` waits for a configurable default two seconds, then opens three onboarding pages. Next/Back/Skip/Get Started navigate to `LoginScreen`. There is no saved onboarding-completed flag, token restore, or authenticated launch route.

**Student authentication: simulated/unfinished.** `_LoginScreenState._bypassLoginForDevelopment` is always true. `_submitLogin()` immediately opens `/home` without validation. If manually disabled, the fallback compares against a hard-coded mock account rather than `AuthService.authenticate()` or Hive. No credentials are reproduced here.

**Registration: partial mock only.** `RegisterScreen._submitRegistration()` validates names, email shape, minimum six-character password and confirmation; it then calls `AuthService.registerUser()`. That service saves email/password pairs only in a static in-memory map; collected names are not persisted. It does not create a Hive `User`, and normal login does not use that map. Accounts disappear after process restart.

**Profile persistence: implemented repository capability, missing account integration.** `HiveRepository.saveUserProfile()` normalizes/uniquely validates email. The active UI is not associated with an authenticated `userId`; `AppState` loads `initialPreferences.userId`, and saves default to `AppUserIds.demo`. No user profile editor, password reset, school verification, email verification, or student account separation was found. Logout only clears routes to login and leaves `AppState`/Hive data intact.

### 3.2 Rehearsal session configuration and speech modes

**Implemented setup UI and validation.** `PracticeSetupScreen` requires speech title and explicit speech type/language/duration selection. Types are only Prepared, Persuasive, Impromptu. Duration choices: 1, 3, 5, 10 minutes or No fixed duration. Language choices: English, English–Filipino, English–Bisaya, Mixed Language.

Prepared/Persuasive require a successfully selected document name and non-empty extracted/editable script. Replace/remove actions exist. Impromptu clears script/document state and omits the script workflow. Monitoring flags are copied from saved preferences; language/duration defaults exist in the model but are not applied to setup, which intentionally begins with null selections.

**Language mode has limited functional effect.** It is stored/displayed as metadata. The Whisper request does not send a language field derived from the selection, and the filler lexicon remains the same for every mode. There is no Impromptu topic generator or separate persuasion/content evaluation.

### 3.3 Device Check, camera preview, and readiness

**Device Check: partial.** `_DeviceCheckScreenState._recheck()` animates camera/microphone rows sequentially using delays. Those rows eventually display Ready without querying actual camera/microphone availability or permission. Internet is a real reachability check with subscription updates. The Camera Preview button is disabled while checking or when internet is unavailable.

**Camera preview: implemented native integration; device verification needed.** `_prepareCamera()` requests camera permission, prefers front camera, falls back to first camera, requests `ResolutionPreset.high`, `enableAudio: false`, Android YUV420 and minimum zoom. `_CameraStage` uses orientation-aware aspect ratio and `BoxFit.contain`. The frame is 9:16 portrait / 16:9 landscape, max 430 logical pixels portrait with a height-aware landscape bound. Letterboxing is intentional.

**Pre-rehearsal readiness: implemented.** Camera preparation occurs before `_hasStarted`. The student can adjust framing/lighting/posture manually before I'm Ready. Lighting is an instruction, not a measured algorithm. Pose/framing inference currently starts only after the countdown, so the readiness preview has no actual live posture/framing meter.

**Ambient noise: implemented RMS prototype.** `AmbientNoiseService` samples mono PCM16 for 2.5 seconds, calculates whole-window RMS, releases the microphone, and refreshes after a 0.5-second gap. Quiet/Moderate/Noisy and Unavailable are shown; Noisy offers Continue anyway. Unavailable retries after five seconds and does not itself block starting. The user should remain silent. It is not VAD, a decibel/SPL meter, or a continuous rehearsal noise detector.

`_beginCountdown()` cancels noise input and waits for its release; rechecks internet; then shows 3 → 2 → 1. Readiness/countdown time is excluded from the visible rehearsal timer. Camera-permission failure does not independently prevent the Ready action, and recording startup failures currently still allow the flow to enter a timed rehearsal (see section 7).

### 3.4 Recording, microphone meter, and rehearsal controls

**Recording: implemented integration, with startup/lifecycle limitations.** `RehearsalAudioRecorder.start()` checks `record` microphone permission. Live disabled uses mono 16 kHz AAC/M4A. Live enabled with fillers or pace selected requests mono 16 kHz signed PCM16, writes the full PCM file and splits the same samples into 10-second chunks; at end it wraps the full capture as WAV. Startup stream failure falls back to AAC. An error during an already-running PCM stream can make final recording unavailable rather than recovering a complete file.

The camera does not capture audio; the separate recorder does. The green microphone indicator uses the same recorder's amplitude stream at 100 ms intervals, with levels below/equal to −50 dB suppressed. It is actual input-volume visualization, but background noise can move it because it does not identify speech.

**Controls: implemented UI/logic, partial correctness.** Camera off stops pose and pauses preview. Microphone off pauses audio while the rehearsal timer continues. Fixed durations count down, warn at 30 seconds remaining, and auto-end; open-ended sessions show elapsed time. Restart confirmation discards current audio and clears live pace/filler/pose states, but pose reinitialization after restart has a control-flow defect. End/back confirmation is provided; preview/countdown cancellation avoids saving an incomplete report. There is no public separate pause/resume session button.

**Wake-lock: implemented wrapper.** `ScreenAwakeService` uses `WakelockPlus`. The rehearsal screen enables it after startup and disables it on end, disposal and app pause. Native timeout prevention was not phone-tested in this audit.

**Video recording: unused capability.** `_toggleRecording()` contains start/stop video code but is annotated unused and has no current UI action. The normal reachable flow records microphone audio, not video. If that legacy method becomes reachable, the returned video path/retention needs explicit handling.

### 3.5 Groq Whisper and optional near-real-time speech feedback

**Final transcription: implemented cloud integration; live service verification needed.** `_finishRehearsal()` stops audio, waits for live chunk processing, checks internet and sends the full temporary recording through `GroqTranscriptionService.transcribe()`. That service posts multipart audio to the Groq audio-transcriptions endpoint with `whisper-large-v3-turbo`, JSON response and bearer authentication. It parses only returned text, with failures for absent config/audio, size, connectivity, timeout, API status, invalid response and empty transcript.

The final request includes `fillerAwarePrompt` asking to preserve audible multilingual fillers. Live requests reuse the same key/service with an eight-second timeout and no such prompt. No second speech-to-text provider/model is present. No API subscription/quota-management UI, proxy backend, automatic retry/backoff, or deferred offline final upload exists.

**Live feedback: implemented chunk-upload architecture; currently blocked by filler compilation.** `_startAudioRecording()` requests chunks only when Live Feedback and at least one of filler/pace monitoring are on. `LiveFillerFeedbackService` sends one request per processed 10-second chunk, then feeds the same partial transcript to filler detection and pace. One request is active, at most one newer PCM chunk waits; a newer chunk replaces an older queued one. Partial final chunks below 10 seconds are retained in full audio but are not submitted live.

The first new filler in a partial transcript generates a 2.4-second non-blocking alert. The service suppresses repeated previous-tail/current-prefix words and identical adjacent transcripts. This is a heuristic: a genuinely repeated phrase/filler across disjoint chunks may also be suppressed. Only the first eligible filler per chunk is alerted, not every recognized occurrence. Live pace shows a rolling average label. Failed chunks are skipped, preserving previous pace. There is no VAD or speaker recognition, so silence/noise hallucinations from Whisper remain possible.

Live OFF produces no live Whisper requests and still uses full audio for the final request, provided compile-time config and recording succeed. Real speech alerts can arrive after 10 seconds plus upload/transcription latency; they are not true streaming responses. Live detection does not update `_fillers`, which represents manual test counts. The live filler-count card therefore remains After session for normal live alerts; final counts come from the full transcript.

### 3.6 Filipino-Bisaya filler analysis

**Current status: broken source; intended deterministic matcher and integrations are present.** `FillerAnalysis.fromTranscript()` lowercases, normalizes curly apostrophes, tokenizes whole Unicode words and tracks canonical fillers/normalized string offsets. The visible rules cover um, uhm, ah, ano, parang, kasi, kuan, kanang, bitaw, mura'g; repeated-ending variants and `kwan`/`murag` aliases are included in the code structure.

The current `kwan` conditional is missing its opening brace and is followed by a closing brace. Analyzer/test compiler errors prevent the factory and its consumers from functioning. The latest inspected branch also lacks the earlier `ku'an` alias, even though `test/filler_analysis_test.dart` explicitly expects `Ku'an`, `kuan`, and `Ku’an` to count together. Fixing syntax alone will not satisfy that alias test.

Counts/rate are computed from the final transcript; words Whisper omits cannot be detected later. Dictionary terms such as kasi/parang/bitaw may be meaningful words; contextual filler discrimination is missing. There is no acoustic hesitation detector or validated precision/recall evaluation.

`HiveRepository._recordsFromPracticeSession()` generates one log per word/session using transcript offsets, with `detectedTimes` empty. These are string positions, not elapsed seconds or word timestamps. Summary counts and logs use the same analysis; repeated saves are guarded. Existing timestamp-based logs can still be read.

### 3.7 Speaking pace

**Final WPM logic implemented; report integration currently compiler-blocked.** `SpeakingPace.fromTranscript()` counts Unicode recognized words, preserving contractions/hyphenation, and divides by total rehearsal minutes. Missing/punctuation-only text or nonpositive duration gives unavailable WPM. Reports/history use `PracticeSession.speakingPace`, which derives from `textTranscript` and session duration. The repository saves `totalWords`/`wordsPerMinute` into `PerformanceReport`.

**Live pace implemented.** The existing shared chunk result is evaluated over the configured 10 seconds. At least four words are required. The display averages the latest three valid chunk WPM values; empty/failed/short transcripts leave it unchanged. Live values are never saved as final WPM.

The final denominator is `_elapsedSeconds` from periodic timer ticks, not measured captured sample duration. It includes silence/mic-muted periods and has confirmation/background timing inconsistencies. This rate is delivery rate over the session, not articulation rate over detected speaking-only time. The 120–160 target is a prototype rule without app-specific educational calibration evidence.

### 3.8 MediaPipe Pose, posture, and camera position

**Pose pipeline implemented for Android; accuracy/native lifecycle verification needed.** `MainActivity.kt` loads the bundled lite model, configures one pose and LIVE_STREAM, and returns shoulders 11/12 and hips 23/24. A single executor runs conversion/inference off the Flutter UI thread. Dart/native gates limit to one in-flight frame; default Dart interval is 500 ms (maximum approximately two requests/sec), skipping frames rather than queueing. YUV conversion downsamples to a default 384px maximum dimension. Frame results include conversion/inference timing and size diagnostics.

**Posture analysis implemented as prototype geometry.** `PostureAnalyzer` checks landmark visibility and computes shoulder tilt/torso lean. `PostureSessionTracker` smooths labels over five valid frames and accumulates time only between nearby valid results. Final posture is the rounded acceptable-valid-time percentage, with insufficient data shown as unavailable. It does not analyze head, legs, hand gestures, detailed spine curvature, or medical posture. Normalized x/y angle calculations do not compensate for camera-image aspect ratio, which needs portrait/landscape accuracy verification.

**Persistent posture warnings implemented.** `PostureWarningController` requires three seconds Adjust or missing landmarks, then two seconds good/visible recovery. Missing takes priority; an existing Adjust warning clears immediately on an invalid frame before the missing warning delay expires. UI uses a persistent card and ValueNotifiers. The warning card is gated by body monitoring and Live Feedback; pose processing can still run when Live Feedback is off. Timers depend on successful sample timestamps and have no independent missing-callback watchdog.

**Camera framing implemented, feedback only.** `CameraFramingTracker` reuses the same four pose landmarks and computes normalized body scale plus hysteresis. It displays Too Close/Proper/Too Far/Unavailable during rehearsal. No additional camera, inference, score, or Hive field is created. Missing/low-confidence data is unavailable rather than Too Far. It estimates frame occupancy, not meters, gaze, or full head-to-waist visibility. Thresholds require physical-device calibration.

**Debug overlay implemented.** `PoseLandmarkOverlay` draws shoulders/hips and torso connections with contained-image/mirroring transforms. Its toggle defaults off and appears only in debug builds (`kDebugMode`). It is a four-point torso overlay, not a rendered full 33-point skeleton. Accurate alignment on actual cameras has not been verified here.

### 3.9 MediaPipe Face and camera-facing attention

**Face Landmarker: missing.** No face model, FaceLandmarker implementation, gaze/head-direction algorithm, or native face channel was found. The shared Tasks Vision package does not prove face functionality.

**Camera-facing attention: simulated placeholder.** `_attention` initializes/resets to 82 and no actual update algorithm was found. Live UI shows 82%, reports save it as attention/camera score, and repository `cameraFacingSeconds` is estimated from session duration × that value/100. Monitoring OFF hides the live card value but does not eliminate the placeholder final result. No genuine looking-away notification is implemented in the current flow. The Settings description promising look-away reminders is unsupported.

### 3.10 PDF/DOCX/TXT uploading and comparison

**Local extraction implemented.** `SpeechDocumentService.pickAndExtract()/extractBytes()` enforce 10 MiB file size, allow PDF/DOCX/TXT, and return filename/text. PDFs use PDFium text layers, max 100 pages; image-only/scanned/password-protected/corrupt documents have explanatory errors. DOCX reads `word/document.xml`, bounds its body at 4 MiB, parses runs/paragraphs/tabs/breaks with XML. TXT tries UTF-8 then Latin-1, strips BOM and normalizes whitespace. TXT/DOCX extraction runs through `compute()`; there is no OCR or cloud document upload.

The UI requires an uploaded file, even though extracted text is editable. Paste-only reference creation is not supported by the current validator. Extraction bounds script text at 120,000 characters; later manual edits are not similarly length-limited in the form, though comparison itself safely checks length.

**Comparison implemented and wired, with downstream report compile blocker.** `ScriptComparisonService` performs order-sensitive word-level longest-common-subsequence alignment, not semantic/content grading. It groups reference-only omissions, transcript-only additions and replacement Expected/Spoken phrases. Coverage is matched reference words / total reference words ×100; additions may coexist with 100% coverage. Prepared/Persuasive run comparison in `compute()` after final transcription; Impromptu does not. The reference script/results are stored with the report.

Limits: 120,000 characters per text and 8,000,000 remaining LCS cells after common prefix/suffix removal. Empty/missing/too-long text is unavailable, not a failure grade. Word order changes and legitimate paraphrases reduce exact match coverage; Whisper errors can look like delivery differences. Old reports without comparison status are recomputed synchronously in `PracticeSession.scriptComparison`, potentially during widget build. Matched-phrase lists are not persisted/displayed alongside every report; stored totals/differences drive the shared summary.

### 3.11 Reports, scoring, and coaching

**Report generation/display/saving: implemented, mixed measurement provenance.** `_finishRehearsal()` creates a `PracticeSession`, then `AnalyzingScreen` waits a default two seconds and opens `ReportScreen`. Real transcription/pose/comparison work occurs before that presentation delay. Reports show transcript WPM/filler-frequency cards, posture score/availability, placeholder camera score, script differences, fixed recommended posture, and rule-based tips.

**Individual scoring: partial.** Posture percentage is based on actual pose valid time. Final pace/filler 0–100 scores remain demo formulas disconnected from actual transcript-derived WPM/counts. Camera score is fixed. Those demo category values remain saved and consumed by strengths/weakest-area summaries even though the main report now shows real rate cards instead of pace/filler scores.

**Overall performance: placeholder rule system.** `_calculateOverall()` runs before final transcription and uses manual filler test counts, the latest posture label, constant attention, and simulated pace state. There is no weighted aggregate of final measured categories. Script coverage does not affect it. Validated score weights or a grading rubric are absent.

**Coaching: partial deterministic recommendations.** `_buildTips()` uses manual filler/test pace/latest posture state and constant attention, not final transcript measurements or Groq-generated coaching. When no rule triggers, it can praise strong pace/eye contact despite no measured eye contact or even missing transcript. `_recommendedPosture` is a fixed string. Progress/Home also infer recommendations from legacy numeric category scores.

Saving requires explicit Save to Progress; returning home or practicing again can leave the current report unsaved. A repeated save does not duplicate the report/session. No report export, sharing, or recording playback UI is implemented.

### 3.12 History, progress analytics, ranking, and goals

**Implemented local analytics.** Progress uses saved `PracticeSession` aggregates: average score, summed practice time, chronological history, latest-vs-previous score difference, descending overall-score ranking, and details navigation. This is ranking the user's local rehearsals, not ranking students or a teacher leaderboard.

`ProgressChart` plots the last six sessions in chronological order with date/score labels and evenly spaced points. The display clamps vertical positions to 40–100, so scores below 40 sit at the chart floor even though their labels show the real number. Inter-session days are not proportional on the x-axis.

Home's goal counts up to three sessions within six whole days of the latest saved session, rather than the current date/calendar week. An old successful week can continue appearing completed. Score-based trends/rankings are functionally rendered but do not establish valid learning progress until scoring is corrected. Four synthetic demo sessions are seeded/restorable and included without per-card differentiation.

### 3.13 Hive persistence and settings

**Actual persistence implemented.** `main.dart` initializes typed boxes; `AppState.initialize()` seeds demo data once and loads sessions/preferences. `saveCompletedRehearsal()` creates normalized profile/session/log/report records, validates parent/ownership IDs and score ranges, prevents duplicate reports, and attempts rollback on save failure. These are sequential multi-box writes, not an atomic transaction; process interruption/rollback failure is not fully covered.

Prepared/Persuasive require a reference profile; Impromptu must not have one. Each currently saved scripted rehearsal receives a new `speech-{sessionId}` profile rather than reusing/editing a saved profile through UI. `getSpeechProfiles()` is a repository capability with no script-library screen.

Reports load through a session/report join; UI recomputes WPM and fillers from stored transcript rather than exclusively trusting stored summaries. Changing the lexicon later can make reopened counts differ from previously stored logs/summaries.

**Settings implemented with incomplete semantics.** Monitoring and Live Feedback flags persist and are copied into future setup. `alertFrequency` persists but has no timing consumer in rehearsal; changing Low/Balanced/Frequent does not change alert behavior. `defaultLanguage`/`defaultDuration` are retained model data without current settings dropdowns or setup application. No vibration implementation was found.

Clear Prototype Data deletes sessions/reports/logs and now-unused profiles whose reports are marked prototype. Both real new rehearsals and synthetic demos are always saved with `isPrototypeData: true`, so clearing removes both; the label does not reliably distinguish measured sessions from dummy data. Profiles/preferences/user metadata are otherwise retained. `deleteSessionWithRelatedData()` exists but has no individual-delete action in history. Restore Demo Sessions adds missing sample IDs without duplicating existing ones.

### 3.14 Offline operation and connection messages

**Connectivity messages implemented.** `InternetConnectivityService` uses a three-second reachability interval; `ConnectionNotice`, installed above the navigator, displays initial online/offline and reconnection changes for three seconds across screens/dialogs. It suppresses repeated identical state and stops/restarts subscriptions with app lifecycle. Device Check also monitors reachability.

**Offline rehearsal mode: missing.** Local saved history/settings can be viewed offline. Device Check and I'm Ready require internet even with Live Feedback off. Losing internet during an active rehearsal does not intentionally stop timer/full recording; failed live chunks are skipped. If internet is absent at final submission, the report continues with unavailable transcript and the audio is deleted. There is no retained upload queue/retry, offline STT, or guaranteed recovery of the transcript after reconnection. Generic reachability does not prove Groq authentication, quota, or endpoint availability.

## 4. Actual End-to-End Rehearsal Workflow

This is the connected source flow once the current compiler blocker is repaired; it was not a physical-device execution during this audit.

1. `main()` initializes Hive and constructs `AppState`. Failure creates an in-memory state with a visible storage error. `SpeakSyncApp` wraps navigation in app state/timing and global connectivity monitoring.
2. Splash opens onboarding. Onboarding always routes to login. Sign In currently bypasses credentials and opens `MainShell`. Registration is an independent in-memory mock and does not create the active data owner.
3. App initialization seeds four demo sessions/preferences once, then loads demo-user history. Home shows aggregates from those records plus subsequent saved rehearsals.
4. Start Practice opens `PracticeSetupScreen`. Student enters title, chooses one of three speech types, chooses language/duration, and sets monitoring/live flags. Prepared/Persuasive require PDF/DOCX/TXT extraction and non-empty script; Impromptu clears it.
5. Continue stores `PracticeSettings` in memory and opens Device Check. Camera/microphone Ready states are delayed placeholders; internet state is real. Online enables Camera Preview.
6. `RehearsalScreen` requests camera permission, opens one camera preview, then repeatedly samples ambient noise with a separate short-lived audio input. No rehearsal timer, chunk uploads, or pose statistics run yet. Lighting/body-position preparation is manual.
7. I'm Ready cancels/releases ambient input. Noisy asks whether to continue. Connectivity is rechecked. A three-second countdown begins; cancellation/backgrounding before startup returns safely to preparation.
8. `_startAfterCountdown()` attempts microphone startup. With live enabled and filler or pace selected, PCM capture feeds both full audio and 10-second chunks; otherwise AAC full audio is used. The flow then starts timer, wake-lock and pose. Currently it starts these even if recording startup returned an error.
9. Each live chunk is transcribed once. Its result feeds the existing filler matcher and rolling WPM. Pose frames at at most two per second feed posture tracking, persistent warnings, framing and optional debug overlay. Fixed camera attention and manual test controls coexist with the real analysis.
10. Camera/mic toggles modify capture; timer continues when mic is off. Restart discards current audio and resets transient state. The current restart guard can leave pose stopped. Fixed duration auto-ends; End/back prompts for confirmation.
11. `_finishRehearsal()` cancels timer, stops pose, snapshots valid posture percentage, stops recorder, waits for live work, checks internet and sends full audio once to final Whisper. Failures produce a report with unavailable transcript. Final temporary audio is deleted even on failure.
12. Prepared/Persuasive reference text and final transcript undergo bounded background LCS comparison. A new `PracticeSession` combines real transcript metrics/pose percentage with placeholder scores/attention/coaching. Live totals/pace are not substituted for the final transcript.
13. AnalyzingScreen provides a short presentation delay and transient failure explanation. ReportScreen displays metrics and differences. Transcription failure reason is not a dedicated persisted report field, so reopened history mainly shows transcript-unavailable explanations.
14. Save to Progress calls `AppState.saveCurrentReport()` and repository mapping/validation. Successful save refreshes demo-user aggregates from Hive. View Progress/Session Details reload those records. Practice Again opens a fresh empty setup rather than automatically reusing the previous profile/settings.

## 5. Algorithms and Scoring

### Transcript pace and filler rules

| Calculation / rule | Actual source behavior | Evidence |
| --- | --- | --- |
| Word count | Unicode letters/numbers with combining marks; internal straight/curly apostrophes and hyphens retained; punctuation-only tokens excluded. | `SpeakingPace.fromTranscript()` |
| Final WPM | recognized word count / (`duration.inMicroseconds / microsecondsPerMinute`) | `speaking_pace.dart` |
| Pace classification | <120 Slow; 120–160 inclusive Target / Effective; >160 Fast | `SpeakingPace.classification` |
| Live chunk WPM | recognized words / (10/60); equivalent to six times word count for default complete chunk | `LiveFillerFeedbackService.handlePartialTranscript()` |
| Live smoothing | Arithmetic mean of latest three valid chunk WPMs; min four words per chunk | Same service, `minimumPaceWords`, `paceWindowSize` |
| Filler normalization | Lowercase and curly-to-straight apostrophes; punctuation handled by Unicode token extraction | `FillerAnalysis.normalizeTranscript()` / factory (currently broken) |
| Canonical dictionary | um, uhm, ah, ano, parang, kasi, kuan, kanang, bitaw, mura'g | Filler factory rules |
| Variations | `um+`, `uh+m+`, `ah+`; kwan -> kuan; murag -> mura'g. Ku'an alias is currently absent despite tests expecting it. | Filler factory / `filler_analysis_test.dart` |
| Fillers/minute | total dictionary occurrences / session duration in minutes | `FillerAnalysis.perMinute` |
| Frequency interpretation | <2 Very Low; [2,6) Low / Acceptable; [6,12) Elevated; >=12 High | `FillerAnalysis.classification` |
| Missing data | Null/empty/punctuation-only text: unavailable; zero duration preserves counts but rate unavailable | Pace/filler getters |
| Filler alert | Earliest eligible canonical filler per chunk after repeated-prefix filtering; 2.4s overlay | Live service / `_showAlert()` |

These rates are transcript estimates. Whisper normalization, omission, hallucination, language mixing and background speakers can affect accuracy. No independently annotated student speech dataset or validation metrics were found.

### Noise and microphone amplitude

`Pcm16Rms`: decode signed little-endian 16-bit samples; normalize each `x = sample / 32768`; accumulate sum of squares and count; `RMS = sqrt(sum(x²) / N)`. Split bytes across buffers are retained. No samples, error/ended stream, or fewer than 8,000 samples returns unavailable.

| Ambient classification | Normalized RMS |
| --- | --- |
| Quiet | <0.01 |
| Moderate | >=0.01 and <0.05 |
| Noisy | >=0.05 |

Default sample duration: 2,500 ms; normal refresh gap 500 ms; error retry five seconds. Requested auto-gain, echo cancellation and noise suppression are disabled, but hardware processing can still vary. Digital silence from a blocked/muted mic cannot be distinguished from a quiet room using RMS alone.

`RehearsalAudioRecorder.levelFromDecibels()` returns 0 for non-finite or <=−50 input; otherwise `clamp((dB + 50) / 40, 0, 1)`. This is the live microphone-volume meter, distinct from readiness RMS.

### Pose, posture duration, and warning timing

Required points: left/right shoulder and left/right hip. Native minimum detection/presence/tracking confidence is 0.5; Dart minimum point visibility is 0.6. Missing/non-finite/low-visible points or degenerate shoulder/torso geometry invalidate posture.

```text
shoulder tilt = atan2(abs(rightShoulder.y - leftShoulder.y),
                     abs(rightShoulder.x - leftShoulder.x)) * 180/pi

torso lean = atan2(abs(shoulderMid.x - hipMid.x),
                  abs(shoulderMid.y - hipMid.y)) * 180/pi

acceptable = shoulder tilt <= 10 degrees AND torso lean <= 12 degrees

posture percentage = acceptable valid duration / total valid duration * 100
```

The display majority window is five valid samples, minimum three samples; ties favor Good. Three invalid samples switch the label to Position yourself. Invalid samples clear continuity but do not clear the stored valid smoothing window. Valid time is accumulated between consecutive valid samples only when their gap is nonnegative and <=700 ms, assigning the interval to the previous classification. Invalid/slow-inference/long gaps are excluded, not scored bad. Minimum valid data is three seconds; otherwise percentage is unavailable and stored posture score is 0 with explicit valid-duration data.

Persistent warning delay is three seconds on the smoothed Adjust signal or continuous unavailable input; recovery is two seconds good/visible. These are timestamp differences between samples, not an independent periodic warning timer. A single invalid sample immediately removes an existing Adjust warning; missing warning then waits its own three seconds. Default 500 ms inference cadence introduces sampling delay, and majority smoothing adds further Adjust delay.

This geometry uses normalized image coordinates directly for angles. Different x/y pixel scaling in portrait/landscape, perspective, camera roll, occlusion and limited landmark visibility can bias it. The thresholds and whether the resulting time fraction is an educationally meaningful score need calibration. No trained custom posture classifier is present.

### Camera framing

```text
shoulderWidth = abs(rightShoulder.x - leftShoulder.x)
torsoHeight = sqrt((shoulderMid.x - hipMid.x)^2 +
                   (shoulderMid.y - hipMid.y)^2)
bodyScale = 0.5 * shoulderWidth + 0.5 * torsoHeight
```

Default below 0.28 -> Too Far; 0.28–0.52 -> Proper; above 0.52 -> Too Close. Hysteresis: current Too Far stays until >=0.31; Too Close stays until <=0.49. Invalid/low-visible input -> Unavailable. There is no score contribution or physical-distance conversion. No degeneracy/out-of-frame coordinate check is added beyond finite/visibility validation in the framing tracker itself; confidence alone cannot guarantee a correct full-body framing judgment.

### Reference-script comparison

`ScriptComparisonService` tokenizes/lowercases words and normalizes apostrophes, aligns ordered words using LCS, groups gaps, and calculates exact reference-word coverage. Common prefix/suffix stripping reduces work; a Uint32 LCS matrix is capped at 8,000,000 cells (about 32 MB for that matrix alone), with overall text limits of 120,000 characters. It assesses wording adherence only, with no factual truth, semantic equivalence or persuasive quality judgment.

### Actual scoring and recommendation sources

| Value | Current calculation | Assessment |
| --- | --- | --- |
| `paceScore` | 94 when `_pace == 'Normal'`, otherwise 72 | Prototype; live/final WPM does not set `_pace`. |
| `fillerScore` | clamp(100 − 7 × `_fillerTotal`, 0, 100) | Prototype manual-test counter; real transcript totals do not set it. |
| `postureScore` | Rounded valid posture percentage, else 0 | Real pose-derived measurement with unvalidated thresholds and availability caveats. |
| `attentionScore` / `cameraScore` | `_attention`, initialized/reset to 82 | Fixed placeholder. |
| `cameraFacingSeconds` | round(sessionSeconds × attentionScore/100) | Derived placeholder, not measured camera-facing time. |
| `overallScore` | Start 100; subtract 3 per manual filler; subtract 8 if latest posture label Adjust; subtract attention deficit below 70; subtract 8 if simulated pace Too Fast; clamp 0–100 | Unvalidated deduction scheme, computed before final transcription. No weighted final-metric calculation. |
| `goodPostureSeconds` | Truncated acceptable duration; legacy fallback estimates from postureScore | Real for current pose sessions; old synthetic records differ. |
| `validPostureSeconds` | Truncated valid duration; null denotes older reports | Used to hide insufficient posture result. |
| Script coverage | matched reference words / reference words ×100 | Separate from delivery/overall score. |
| Tips | Conditional prewritten strings in `_buildTips()`, fixed recommended posture; Home/Progress sort category scores | Not AI-generated and not reliably tied to final measurements. |

A student's real fillers/slow pace can therefore coexist with perfect prototype filler/overall scores. Manual test buttons can change scores despite representing no actual recorded speech. A final 0–100 pace/filler rubric and validated overall weights are unfinished. Do not describe those values as validated AI performance assessment.

## 6. API, Privacy, and Security

### Configuration and requests

`AppConfig` reads `GROQ_API_KEY` from a Dart compile-time define. The intended build/run mechanism is `--dart-define-from-file=.env.json`. This audit checked only safe booleans: local `.env.json` exists, parses as JSON, contains a string property `GROQ_API_KEY`, and that string is non-empty. Its value was not included in this report. `.env.json` is ignored and not listed as a tracked file; `.env.json.example` is tracked. Non-empty configuration is not proof of a valid key/account or of a specific installed APK containing it.

Groq receives HTTPS multipart audio, bearer key, `model`, `response_format: json`, and optional final filler-retention prompt. Language selection is not passed. The service accepts a maximum 25 MiB audio file. Default final timeout is 90 seconds for sending, then another independently applied timeout while reading the response; eight-second live timeout is applied similarly. These are not necessarily single end-to-end 90s/8s budgets.

The app has no account quota check, request-budget tracker, adaptive interval, rate-limit backoff, or key-renewal workflow. Live errors including 429 are skipped and recording continues. With live feedback, nominal usage is about six complete live uploads per minute plus one final full-session upload, subject to pending-chunk drops. Provider pricing/rate limits/retention were not checked during this repository audit and must be verified for the intended account before testing/distribution.

### Data handling

- Readiness noise samples retain only aggregate energy/count and a split byte; app code does not write/upload that sample.
- Actual rehearsal audio is written to the app temporary directory. Live PCM is written to a raw full file plus bounded chunk buffers; each live chunk becomes a temporary WAV and is deleted in `finally`.
- At end, full PCM is converted to WAV and raw PCM is deleted. Final WAV/M4A is deleted after the transcription attempt even when offline/error. No persistent recording path or playback exists in Hive.
- Restarts discard current audio. Cancel/dispose attempts cleanup, but deletion is best-effort; crashes, errors before an output path is assigned, and abrupt process termination can leave temporary files. No explicit startup orphan-cleanup/retention job exists. OS cache management is not proof of immediate erasure.
- Normal reachable rehearsal flow does not save or upload raw video. Camera frames go to local native inference; only selected landmarks return to Dart. The unused video method is a separate retained code path.
- Transcripts, reference scripts/document names, reports, profiles, and preferences persist in Hive. They can contain personal/student information. Boxes are opened without an encryption cipher.
- No teacher sharing, analytics upload, report export, or cloud database was found. Audio cloud transcription is nevertheless an actual external transfer.

### Concrete concerns before external testing

1. **Incorrect privacy statement:** `SettingsScreen._privacy()` says “No cloud upload or automatic sharing.” Groq receives audio. Update disclosure/consent before exposing recording to students; distinguish local visual processing from cloud speech transcription.
2. **Embedded key risk:** compile-time defines keep the key out of Dart source but still embed it in the client build. Distributed APKs cannot reliably protect a shared server credential. A controlled test key and, for broader deployment, a controlled backend/proxy or appropriate secure credential architecture is required. Do not log bearer headers/defines or include secrets in reports/commits.
3. **Credentials already present in prototype source/docs:** the fallback login, mock service and older overview include hard-coded demo authentication data; the service stores passwords in memory as plain strings. Values are intentionally omitted. Remove the pattern before real accounts and rotate any real credential that has been shared outside its intended scope.
4. **No account isolation:** any bypassed login reaches the same demo history/preferences; logout does not clear that state. There is no secure session, authorization, or active-user record ownership enforcement at the UI identity boundary.
5. **Unencrypted sensitive text:** scripts/transcripts/users/reports persist locally without encryption. Decide whether encryption, Android backup restrictions, retention controls and per-record deletion are required for the testing population.
6. **Consent/retention missing:** no durable consent workflow explaining audio upload, provider handling, retention/deletion and student/guardian requirements was found. Provider/legal/school requirements were not independently reviewed here.
7. **Error text sanitation:** `_apiFailureMessage()` may display a short provider error string verbatim. The existing mocked test checks one response does not expose its test key; this is not a general sanitizer for credentials or sensitive provider details.

## 7. Missing, Incomplete, and Potentially Broken Features

| ID | Finding and evidence | Confidence / impact |
| --- | --- | --- |
| F01 | `filler_analysis.dart:21–23`: malformed kwan conditional/brace structure. Analyzer reports cascading syntax/getter errors; test compilation fails. | Confirmed current build blocker. |
| F02 | Ku'an alias absent in latest filler branch, while `filler_analysis_test.dart` expects straight/curly Ku'an -> kuan. | Confirmed source/test inconsistency; likely remaining failing test after F01 repair. |
| F03 | Login bypass true; registration map not connected to login/Hive; AppState/save default to demo user. | Confirmed missing operational authentication/profile isolation. |
| F04 | Settings privacy denies uploads; Groq service posts recorded audio. | Confirmed misleading disclosure, critical external-test concern. |
| F05 | Camera attention fixed at 82, with derived fake camera-facing seconds. No Face pipeline. | Confirmed placeholder shown/saved as result. |
| F06 | Overall/pace/filler scores and coaching use demo counters/state rather than final transcript metrics. | Confirmed integrity problem for progress/strength/weakest-area claims. |
| F07 | Restart keeps `_paused=true` until `_confirmRestart()` finally. `_restartRehearsal()` calls `_startPostureAnalysis()` before then, whose first guard returns when paused. No post-finally start exists. | Strong control-flow evidence that pose/framing stop after Restart; needs widget/native regression test. |
| F08 | `_startAfterCountdown()` sets started/timer/wake-lock/pose after `_startAudioRecording()` even when that function returned missing-key/permission/error state. | Confirmed control flow allows rehearsal with no recording. |
| F09 | `_confirmEnd()` pauses timer/pose callbacks but not microphone or posture clock; dialog audio can enter transcript while duration excludes it. `_finishRehearsal()` also awaits visual cleanup before audio stop. | Confirmed lifecycle mismatch; quantify effect with tests/device capture. |
| F10 | `_startPostureAnalysis()` sets stream active only after async initialization/start without rechecking paused/foreground/generation comprehensively. Stop/reset can race with startup or in-flight results; Dart frame gate reset does not await native request completion. | Potential lifecycle race; native atomic gate limits overlap, but reliability needs interruption testing. |
| F11 | `_analyzePostureFrame()` catches errors without publishing unavailable/resetting timing. Warning timers accept timestamps without maximum-gap validation. | Potential stale feedback or false continuity after long missing callbacks/errors. |
| F12 | On active app pause only pose/wake-lock explicitly stop; audio/live worker/timer are not given a comprehensive background policy. | Source gap; Android may suspend callbacks/recording. Needs physical lifecycle tests. |
| F13 | Camera/mic Device Check Ready values are delay-only; Ready action does not require successful camera or mic startup. | Confirmed partial readiness; inaccurate Ready promises. |
| F14 | Settings alert frequency has no rehearsal consumer; camera-attention reminder toggle has no true detector; live OFF pace may still show Normal with LIVE styling. | Confirmed inert/misleading UI behavior. |
| F15 | Final filler/WPM computations and report category values still execute regardless of their monitoring flags; flags gate live callbacks/display and pose but do not consistently gate final categories. | Confirmed inconsistent meaning of monitoring OFF; define intended semantics. |
| F16 | Manual filler/fast-speech test buttons are shown whenever live feedback is enabled, not limited to debug builds. They alter report demo scores. | Confirmed contamination risk during student tests. |
| F17 | All newly saved records marked prototype; Clear Prototype Data removes measured rehearsals too. Demo sessions blend into rankings/charts; default seeding supplies artificial baselines. | Confirmed provenance/deletion ambiguity. |
| F18 | Final failure deletes recording, and failure reason is not saved as a report field. No retry/deferred upload path. Start is blocked offline even with live OFF. | Confirmed limitation; not operational offline rehearsal. |
| F19 | Posture angles use normalized x/y without pixel/aspect compensation; valid gaps >700ms exclude time on slower phones; visibility window persists through invalid streak. | Potential bias and coverage limitations, not demonstrated native accuracy. |
| F20 | Framing uses shoulders/hips only; can accept finite high-confidence but degenerate/out-of-frame geometry; no head/face/waist verification. | Confirmed scope and validation limitations. |
| F21 | `User` field 5 gap is intentional compatibility; existing adapters require many older nonnullable fields. Only limited legacy-user migration and nullable appended-field compatibility exist. | Renumbering would be unsafe; broad historical migration unverified. |
| F22 | Multi-box saves/deletes are sequential; rollback is best-effort. Validation does not thoroughly enforce finite WPM, duration consistency, or log-summary equality on every independently exposed write. | Potential data-integrity gap outside ordinary save mapping. |
| F23 | Storage initialization failure falls back to in-memory demo state; save can report success without durable storage in that mode. | Confirmed fallback behavior, requires clearer persistent-state UX for real testing. |
| F24 | Home goal anchored to latest session rather than today; chart clamps scores below 40; strength cards pick two highest categories without minimum quality threshold. Home coaching does not exclude unavailable posture. | Confirmed analytics/wording limitations. |
| F25 | Legacy `DashboardScreen` invokes unregistered `/login`; unused `_toggleRecording()`/gesture fields remain. | Confirmed unused/broken legacy path, not part of normal flow. |
| F26 | Profile editing/script library, independent history deletion/export, reminder inbox, pronunciation analysis, VAD, speaker verification, semantic/factual scoring, validated confidence/engagement analysis are absent. | Missing; do not imply through screen text/model field names. |
| F27 | No native iOS runner/face implementation; web scaffold conflicts with IO/native dependencies; release uses debug signing; no current successful build. | Deployment blockers/limitations. |

No source changes were made to fix these findings. Several flow defects are static inferences rather than observed phone failures; those distinctions should remain when planning work.

## 8. Testing and Deployment Readiness

### Validation actually performed in this audit

| Check | Result / evidence |
| --- | --- |
| Source/configuration review | Completed across the listed Flutter/Android/storage/service/screen/test files. Existing dirty changes were included. |
| Safe local Groq configuration check | JSON exists and parses; required key property is a non-empty string. No value printed into this report; validity/quota not tested. |
| `flutter analyze --no-pub` | Exit 1; **77 issues**. Root syntax defect is in filler service; consumers produce cascading errors. |
| `flutter test --no-pub --reporter compact` | Exit 1; **94 passed, 8 failed** in approximately 1m11s. Failures include suites that cannot load/compile due to filler service. This is not a successful full test run. |
| Formatting | Not run, to honor the request not to modify application files. |
| New Android build | Not attempted after the confirmed compilation blocker; no new successful build claimed. |
| Existing APK | `build/app/outputs/flutter-apk/app-debug.apk` exists, 223,416,785 bytes (~213.1 MiB), filesystem timestamp September 20, 2026. It predates this audit/current defect; no installation or contents verification performed. |
| Physical Android / live Groq / native Pose test | Not performed. No claimed real-device accuracy, latency, power/thermal performance or successful live request. |
| iOS/iPadOS/production web/release signing/Play submission | Not verified or executed. |

Prior README/documents and earlier chat/build success results should not replace these current findings. The current full suite cannot prove app-level integration until F01 is resolved and checks are rerun.

### Existing automated coverage

| Test file(s) | What is exercised | What it does not establish |
| --- | --- | --- |
| `ambient_noise_service_test.dart` | PCM RMS, split bytes, boundaries, low/moderate/high input, errors/cancel/permission and cleanup | Real microphone gain or scientifically valid noise labels |
| `camera_framing_test.dart` | Synthetic close/proper/far/missing/confidence cases, hysteresis, reset, unchanged posture input | Native inference accuracy or actual resolution-independent phone behavior; one test repeats identical normalized inputs |
| `filler_analysis_test.dart` | Lexicon, variations including Ku'an, boundaries/offsets/rate/null, legacy adapter, frequency card | Acoustic filler capture or semantic filler-vs-content decisions; currently compile-blocked |
| `groq_transcription_service_test.dart` | Mocked multipart request/model/prompt/filename/text, missing key/API error | Live API key validity, quota, provider behavior or full timeout/failure matrix |
| `hive_repository_test.dart` | Temporary boxes, joins, settings, duplicate guard, ownership/email rules, clear/delete | Process-kill atomicity, all historical schemas or actual phone storage; currently compiler-blocked |
| `live_filler_feedback_service_test.dart` | Shared transcript, 10s pace, rolling average, min words, duplicate filtering, failure/429, bounded processing, stop, final separation | Native capture or actual network latency; currently compiler-blocked |
| `microphone_level_test.dart` | Volume mapping, silent/invalid suppression | Speech identification or native meter performance |
| `pose_landmark_overlay_test.dart` | Coordinate transform, contain/mirror, toggle/painter, orientation rules | Real sensor/preview alignment across vendors |
| `posture_analysis_test.dart` | Synthetic posture/visibility/majority/valid-time percentage/reset and monitoring gate | Native model accuracy, body variability, aspect correction |
| `posture_performance_test.dart` | Gate throttling/no queue/reset, dimension bounds, diagnostics | Actual sustained FPS, thermal load, JNI/native resource behavior |
| `posture_warning_controller_test.dart` | Synthetic warning/recovery timestamps, priority, no repeated state changes/reset | Rehearsal/native restart/pause integration |
| `rehearsal_audio_recorder_test.dart` | Fake native recorder discard/pause, full WAV/chunks, fallback, early samples | Native mic permission/sampling continuity or cleanup on process death |
| `rehearsal_readiness_test.dart` | Fake readiness/noise lifecycle/countdown/wake-lock/live callback gating/error continuity | Real microphone/camera/Groq; currently compile-blocked |
| `script_comparison_service_test.dart` | Exact/omitted/added/replaced/order/repeated words/punctuation/apostrophes, empty/long bounds | Semantic or factual accuracy |
| `script_comparison_report_test.dart` | Appended Hive fields, round trip/reopen, unavailable/Impromptu UI | Phone lifetime migration; currently compiler-blocked |
| `speech_document_service_test.dart` | Synthetic TXT/DOCX/PDF, real local PDFium extraction, file errors/size | Native picker UX, every real-world PDF/DOCX layout, scanned OCR |
| `speaking_pace_test.dart` | Word/duration calculation and 120/160 boundaries, missing data and report UI | Correct capture-vs-timer alignment; UI portion impacted by compile defect |
| `responsive_layout_test.dart` | 324 generated layout cases across nine device/text-scale configurations × two orientations × 18 screen cases | Native iOS support or actual camera stream; currently compile-blocked |
| `widget_test.dart` | Launch/setup/navigation/save/history/settings, timer/restart/back/connectivity using prototype/fake services | Secure auth, live network/native MediaPipe; currently compile-blocked |

Two readiness tests use `skip: !AppConfig.hasGroqApiKey` (silent-recording regression and startup-cancellation case). A placeholder define with fake services can exercise them without using an actual credential. The normal test command does not load `.env.json`. Compiler failures currently prevent a normal skip/pass outcome for that suite.

The widget test named Prototype demo controls are removed checks an old `demo_controls` key and title; it does not assert that current `prototype_alert_controls` / manual filler/pace buttons are absent. Names alone are not proof of behavior.

No `integration_test/`, native Android test suite, CI workflow, device benchmark, end-to-end actual-cloud fixture, student validation dataset, or documented release acceptance run was found in the inspected project files.

### Deployment assessment

- **Developer/alpha build:** blocked by F01. After repair, rebuild with local configuration, verify test-only controls/score disclosure and cloud consent, then run device permission/countdown/restart/network-loss scenarios. The older APK cannot demonstrate current-source readiness.
- **External student beta:** additionally requires operational identity or explicitly scoped anonymous use, correct measurement labels, truthful privacy consent, controlled API usage/credentials, storage/deletion policy, supported Android device validation, and basic security/lifecycle testing.
- **APK distribution:** existing APK is a large debug artifact. Final size, startup/model loading and install compatibility need fresh checks. Confirm key strategy and supported ABIs/devices. Do not distribute a secret-bearing shared debug build as a production solution.
- **Google Play:** release build currently selects `signingConfigs.getByName("debug")`; production signing and app-bundle/release validation are missing. Package/label remain prototype-oriented. Required store/privacy/data disclosures, account behavior, provider terms and current platform requirements were not independently checked in this audit and must be reviewed before submission. No successful release/AAB or store submission is evidenced.

## 9. Development Recommendations

Priorities refer to restoring reliability and aligning claims, not permission to modify code as part of this audit.

### P0: Critical problems or blockers

1. **Restore buildability (F01/F02).** Correct filler factory structure and restore the documented Ku'an spelling behavior. Run analyzer, all tests and a fresh Android build. Retain evidence; do not assume the previous APK reflects the repair.
2. **Correct cloud disclosure and credential handling before external tests (F04).** Explain when rehearsal audio goes to Groq, what stays local and how local audio is deleted. Keep real key values out of source/docs/logs; adopt a controlled test/deployment credential strategy.
3. **Decide and enforce the test identity model (F03).** Implement student authentication and active-user data isolation if capstone requires accounts, or explicitly mark the build anonymous/demo and remove account-success claims. Connect registration/login/profile persistence; logout must have defined state behavior.
4. **Stop presenting unmeasured results as student performance (F05/F06/F16).** Disable/label camera attention, isolate manual demo controls from student sessions, and make scores/coaching accurately reflect availability and provenance. A truthful incomplete report is preferable to fabricated conclusions.
5. **Fix essential rehearsal lifecycle correctness (F07–F09).** Ensure pose/framing resume after restart, do not silently start a no-recording rehearsal, and synchronize timer/audio around confirmation/cleanup. Add focused regressions before alpha testing.

### P1: Missing core requirements / correctness

1. Define/validate final pace/filler score transforms and overall weights with advisers, explicitly handling disabled/missing categories. Base coaching/strengths/weakest-area on actual final measurements and exclude unavailable values.
2. Implement and validate on-device camera-facing/head-direction measurement if required by the capstone. Face Landmarker should be described as planned until integrated and tested; do not equate head facing to proven eye contact or engagement.
3. Calibrate posture/framing/noise thresholds on representative students/devices; review normalized-coordinate angle aspect ratio and valid-duration coverage on slower phones. Report coverage and uncertainty alongside percentages.
4. Define background/pause/camera/error/restart lifecycle state transitions, wait safely for pending native work and clean up stale results. Add device interruption tests and callback watchdog/recovery where warranted.
5. Make camera/mic Device Check truthful; verify actual permissions/input rather than delayed success rows. Define when the student may proceed with unavailable components.
6. Make monitoring OFF and Live Feedback OFF semantics consistent across UI, capture, final analysis and saved reports. Implement alert-frequency timing or remove the inert control; do not show Normal/LIVE when no pace measurement is running.
7. Decide offline rehearsal policy. If allowed, capture locally without internet and securely retain an explicit retry queue until success/user deletion; otherwise accurately explain that network is required and failures are unrecoverable after deletion.
8. Separate synthetic demos from measured records and destructive reset behavior; add individual delete, explicit retention and optional export requirements. Review multi-box crash consistency, migration tests and finite/range validation.
9. Revise README/system overview/data dictionary/help/about and UML/model diagrams using the actual current schema/flows described here. Keep historical implementation notes clearly versioned.
10. Validate live-vs-final filler discrepancies with retained-consent sample clips and annotated expected transcripts. Document lexicon limits/meaningful-word false positives; avoid claiming universal multilingual accuracy.

### P2: Improvements and optional features

1. Add saved-script library/reuse/edit if needed; currently every scripted saved session creates a separate profile. Consider paste-only reference input and readiness framing reuse without contaminating rehearsal duration.
2. Improve progress chart range/date spacing, weekly-goal current-date logic, synthetic-data badges and fair ranking comparability across durations/types/monitoring coverage.
3. Retire unused dashboard/video/gesture fields or complete explicit recording-retention requirements if those features are in scope.
4. Add startup orphan-audio cleanup, anonymized non-secret diagnostics, sustained device performance/thermal tests, accessibility verification and CI checks.
5. Prepare production release signing/labels/icons/versioning and evaluate supported-platform targets explicitly. A web folder/iPhone layout test should not be advertised as a working native platform.
6. Consider OCR, vibration, reminders, report export or teacher sharing only if approved requirements call for them; these capabilities are not currently implemented.

## 10. Feature Verification Matrix

All app-integrated features below are subject to the current global compilation blocker. “Tests present” means inspected test source, not a successful full suite; actual current aggregate result is 94 passed / 8 failed.

| Feature | Status | Source File(s) | How It Works | Missing Work | Testing Status |
| --- | --- | --- | --- | --- | --- |
| Splash/onboarding | Implemented UI | `screens/splash_onboarding.dart`, `app.dart` | Timed launch, pages, skip/login routing | Saved completion/auth restore if required | Widget/layout tests present; current app suites compile-fail |
| Login | Simulated/bypass | `login.dart` | Always bypasses to home; dormant hard-coded fallback | Secure auth, connected registry/session | No operational auth evidence |
| Registration | Partial mock | `register.dart`, `auth_service.dart` | Form validation, static account map | Persistence, login/profile integration, security | No full identity tests found |
| Student profiles | Partial repository | `models/user_model.dart`, `storage/hive_repository.dart` | Hive user validation/storage; shared demo active | Active user binding, editor, isolation | Repository tests present, compile-blocked |
| Logout | Navigation only | `screens/settings_screens.dart` | Confirm then clear navigation to login | Session/data-state invalidation | UI tests present; no secure session |
| Home/dashboard metrics | Implemented local UI | `screens/home_screen.dart`, `state/app_state.dart` | Aggregate saved session count/time/score/delta | Correct/provenance-aware scores and goal window | Widget/layout tests present, compile-blocked |
| Rehearsal setup | Implemented | `screens/practice_flow.dart`, `models/practice_settings.dart` | Required title/type/language/duration and toggles | Consistent monitoring semantics | Setup/widget tests present, compile-blocked |
| Prepared/Persuasive | Implemented document flow | `practice_flow.dart`, `speech_document_service.dart` | Required uploaded/editable reference | Script reuse/paste-only optional; picker device tests | Extractor tests run; UI compiler-blocked |
| Impromptu | Implemented setup mode | `practice_flow.dart`, `script_comparison_service.dart` | No reference/comparison; same recording/language metadata | No topic generator if desired | Comparison/flow tests present |
| Language mode | Partial metadata | `practice_flow.dart`, `groq_transcription_service.dart` | Saved/displayed selection | No language-specific request/lexicon effect | No language-dependent provider test |
| Device Check camera/mic | Simulated readiness | `practice_flow.dart:DeviceCheckScreen` | Delays -> Ready | Actual permission/device/input checks | UI flow only |
| Device Check internet | Implemented | `internet_connectivity_service.dart`, `practice_flow.dart` | Reachability subscription/button gate | Provider-specific availability if desired | Fake-network tests; no real network check |
| Global online/offline messages | Implemented | `app.dart`, `widgets/connection_notice.dart` | Navigator-level 3s transition notices | Device/captive-network validation | Fake navigation/connectivity tests present |
| Camera preview | Implemented native integration | `practice_flow.dart:_prepareCamera/_CameraStage` | Front preference, high preset, minimum zoom, contain fit | Native orientation/device/lifecycle validation | Fallback/layout/transform tests, no actual camera |
| Lighting readiness | Manual guidance | `practice_flow.dart` | User instructed to adjust room/framing | No measured lighting check | No lighting algorithm tests |
| Ambient noise readiness | Implemented prototype | `ambient_noise_service.dart`, `practice_flow.dart` | Automatic 2.5s RMS sampling; warning/override | Device calibration/permission validation | RMS service tests ran; readiness UI compiler-blocked |
| I'm Ready/countdown | Implemented flow | `practice_flow.dart` | Stop noise -> 3/2/1 -> start | Recording-failure guard/lifecycle edges | Fake-flow tests present, compile-blocked |
| Full rehearsal audio | Implemented recording integration | `rehearsal_audio_recorder.dart`, `wav_audio.dart` | Full AAC or PCM/WAV | Capture/time alignment, stream-error/process-death cleanup | Fake recorder tests; no native mic |
| Microphone level | Implemented amplitude | `rehearsal_audio_recorder.dart`, `practice_flow.dart` | Same input amplitude, 100ms, silence threshold | Noise vs speech not distinguished | Mapping tests ran |
| Camera/mic controls | Partial correctness | `practice_flow.dart` | Pause preview/pose or microphone | Consistent missing/off results/lifecycle | UI/source review; no phone toggle verification |
| Timer/automatic completion | Implemented with timing caveats | `practice_flow.dart:_handleTimerTick` | Fixed/open-ended seconds, 30s warning, auto-end | Audio/dialog/background clock consistency | Widget tests present, compile-blocked |
| Restart | Partial/likely pose defect | `practice_flow.dart:_confirmRestart/_restartRehearsal` | Discard/reset/start audio; pose start guarded paused | Resume pose after paused flag clears | Timer tests present; no native restart regression |
| Keep display awake | Implemented wrapper | `screen_awake_service.dart`, `practice_flow.dart` | Rehearsal wake-lock enable/cleanup | Phone timeout verification | Fake controller tests present |
| Final Groq Whisper | Implemented HTTP integration | `groq_transcription_service.dart`, `practice_flow.dart` | Full recording multipart, model/prompt/text | Live key/network/provider validation, retry policy | Mock HTTP tests ran; no live request |
| Optional live chunks | Implemented; integration blocked | `rehearsal_audio_recorder.dart`, `live_filler_feedback_service.dart` | One capture, 10s WAV uploads, bounded pending work | Native capture/latency/quota tests | Shared-request/failure tests present, compile-blocked |
| Live filler alerts | Partial/currently broken dependency | `live_filler_feedback_service.dart`, `filler_analysis.dart` | First eligible filler per chunk, repeated-prefix filter | F01/F02; contextual/duplicate heuristic limits | Tests present, compile-blocked |
| Live pace | Implemented arithmetic; integration blocked | `live_filler_feedback_service.dart`, `speaking_pace.dart` | >=4 words, latest 3 mean, 10s denominator | Device speech/latency evaluation | Unit/widget cases present, dependent suite blocked |
| Live OFF API reduction | Implemented gate | `practice_flow.dart:_startAudioRecording` | No chunks; full AAC/final request preserved | Clarify posture/status behavior OFF | Fake request-gating tests present, compile-blocked |
| Final localized fillers | Broken current source | `filler_analysis.dart`, `filler_frequency_card.dart` | Whole tokens, canonical counts/rate | Syntax/Ku'an fix, accuracy study | Compile failures; expected alias case inspected |
| Detailed filler logs | Implemented mapping; blocked | `filler_word_log.dart`, `hive_repository.dart` | One canonical log/session; offsets not timestamps | Actual timestamps only if requirement demands | Adapter/repository tests present |
| Final WPM | Implemented calculation | `speaking_pace.dart`, `practice_session.dart`, `hive_repository.dart` | Final words / total rehearsal minutes | Accurate denominator capture policy | Arithmetic tests observed; report UI compile-blocked |
| MediaPipe Pose | Implemented Android native | `MainActivity.kt`, `posture_landmarker_service.dart`, bundled model | One LIVE_STREAM pose, four returned points | Native model accuracy/resource/lifecycle testing | No native inference test run |
| Pose performance gate | Implemented | `posture_performance.dart`, native atomic gate | 500ms, one active frame, no queue, 384px default | Sustained real-device benchmark | Synthetic gate tests ran |
| Posture assessment | Implemented prototype | `posture_analysis.dart`, `practice_flow.dart` | Angles, majority, valid-time percentage | Calibrate/aspect correction/coverage validation | Synthetic tests ran; native unverified |
| Persistent posture warning | Implemented controller | `posture_warning_controller.dart`, `practice_flow.dart` | 3s issue / 2s recovery, persistent card | Gap/error/restart integration verification | Controller tests ran; no native UI test |
| Camera Position | Implemented feedback | `camera_framing.dart`, `practice_flow.dart` | Same pose, normalized scale, hysteresis | Calibrate, readiness use optional, geometry validation | Synthetic tests ran; phone unverified |
| Debug torso overlay | Implemented debug only | `pose_landmark_overlay.dart`, `practice_flow.dart` | Four points, contain transform, mirrored front | Physical alignment/rotation verification | Painter/transform tests ran |
| Face Landmarker | Missing/planned | No face implementation/model found | No active code | Integrate if core requirement | No face tests found |
| Camera-facing attention | Simulated | `practice_flow.dart:_attention`, `hive_repository.dart` | Fixed 82 and derived seconds | True head/camera-facing measurement | Tests assert placeholder; no accuracy evidence |
| PDF/DOCX/TXT extraction | Implemented local | `speech_document_service.dart` | PDFium/text, ZIP/XML, UTF-8/Latin-1 | OCR optional, real picker/docs validation | Extraction/error tests observed passing |
| Script comparison/coverage | Implemented deterministic | `script_comparison_service.dart`, shared summary | Bounded ordered LCS and grouped differences | Legacy synchronous path/performance verification | Algorithm tests ran; report/storage suites blocked |
| Report screen | Implemented but mixed/blocked | `practice_flow.dart:ReportScreen` | Rates, pose/attention, transcript, comparison/tips | Accurate scores/availability/failure provenance | Widget tests cannot compile currently |
| Coaching/recommended posture | Partial rule/static | `_buildTips`, `home_screen.dart`, `progress_screens.dart` | Prewritten strings from demo states/scores | Base on measured results and uncertainty | No recommendation validity study |
| Pace/filler 0–100 scores | Simulated/unfinished | `practice_flow.dart:_finishRehearsal` | Demo state/counter formulas | Validated final metric-to-score rules | No validated rubric tests |
| Overall score | Simulated/unfinished | `practice_flow.dart:_calculateOverall` | Prototype deductions before transcript | Approved weighted/provenance-aware scoring | No validity study |
| History/session details | Implemented local persistence | `progress_screens.dart`, `hive_repository.dart` | Session/report join and reopen | Per-session delete/export, consistent metrics | Repository/UI tests present, compile-blocked |
| Progress trend/improvement | Implemented presentation | `progress_screens.dart`, `common_widgets.dart` | Last 6 chart, averages/deltas | Score validity, floor/date semantics | Layout/UI tests blocked |
| Rehearsal ranking | Implemented local sorting | `progress_screens.dart` | Overall score descending, details links | Measurement validity/fair comparability | No student leaderboard; UI tests blocked |
| Weekly goal | Partial calendar semantics | `home_screen.dart` | Three sessions near latest saved date | Anchor to intended current period | No current-date goal regression found |
| Hive boxes/adapters | Implemented | `models/*.dart`, `storage/*.dart`, `main.dart` | Registered types 0–5, seven boxes | Encryption, complete migration/crash testing | Storage/compatibility tests present, affected by compile blocker |
| Save duplicate protection | Implemented | `AppState.saveCurrentReport`, `saveCompletedRehearsal` | Session/report ID guard; stable filler log IDs | Concurrency/crash recovery hardening | Duplicate tests present, compile-blocked |
| Clear/restore data | Implemented with provenance issue | `settings_screens.dart`, `hive_repository.dart` | Delete prototype-linked records; restore four demo IDs | Distinguish measured vs dummy/all-data deletion | Tests present; measured data marked prototype |
| Monitoring settings | Partial semantics | `settings_screens.dart`, `app_preferences.dart` | Persist and copy flags into setup | Consistent final OFF handling, true attention | UI/repository tests blocked |
| Alert frequency/defaults | Saved but unused/inert | `app_preferences.dart`, `settings_screens.dart` | Frequency stored, defaults retained | Consumer logic or clear UI scope | No effect test found |
| Responsive layout | Implemented techniques | `common_widgets.dart`, screens/rate cards | Constraints, scroll, flexible grid, text scale | Native device/notch/camera verification | 324 cases defined; suite compiler-blocked |
| Offline local history | Implemented storage capability | `AppState`, `HiveRepository` | Existing reports/preferences are local | Real offline phone test | No native offline test |
| Offline capture/upload retry | Missing | `DeviceCheckScreen`, `_beginCountdown/_finishRehearsal` | Online gate; final failure deletes audio | Explicit offline queue/retention/retry if required | Failure-path mocks, no recoverable offline workflow |
| Video recording | Unused | `practice_flow.dart:_toggleRecording` | Dormant camera recording method | Remove or intentionally connect/retain/delete | No reachable recording verification |
| Gesture detection | Missing; legacy fields | `practice_session.dart`, `practice_flow.dart` | Empty gesture map, no detector | Implement only if requirement | No gesture algorithm tests |
| Export/teacher sharing/reminders | Missing | Home notifications placeholder; no export/share service | Notification button only shows caught-up message | Approved features/integrations | No implemented-feature tests |
| Secure production release | Missing | `android/app/build.gradle.kts` | Release currently debug-signed | Production signing/AAB/privacy/device acceptance | No new release build or submission |

## 11. Documentation Alignment Notes

### Features that can be described as implemented in source

Use wording such as “implemented in the current prototype, pending restored build and physical validation” for camera/readiness/countdown, actual recording, final Groq Whisper integration, 10-second shared live transcripts, deterministic WPM, local script extraction/LCS comparison, Android MediaPipe Pose, normalized camera-position feedback, local Hive saving, and history/analytics screens. Filler detection must additionally be called currently broken pending F01/F02. Do not claim a deployable working system from source presence while compilation fails.

After validation, describe their exact scope: cloud speech transcription plus local rule-based analysis; on-device shoulder/hip posture; chunk-based near-real-time alerts; frame-occupancy estimates; and local rehearsal ranking. Avoid claiming true streaming, calibrated physical distance, contextual filler understanding, factual/semantic grading, or gaze from these implementations.

### Features that must be described as planned, simulated, or incomplete

- Operational student authentication, persisted registration and active user isolation: incomplete/mock.
- MediaPipe Face Landmarker, true camera-facing/eye-contact detection: planned/missing. Fixed camera score remains simulated.
- Final pace/filler 0–100 scoring and validated overall scoring: incomplete prototype rules.
- AI-generated coaching, confidence/emotion/audience engagement assessment, pronunciation scoring, VAD/speaker recognition: missing.
- Genuine offline rehearsal and queued transcription retry: missing.
- Measured lighting readiness, full-body/head framing verification, gesture recognition: missing/manual guidance only.
- Alert-frequency behavior: unused selection; vibration: absent.
- Native iPhone/iPad support, secure public deployment, release signing/Play readiness: unverified/missing.

### Claims requiring verification before inclusion

Require successful current analyzer/tests/build and actual phone evidence for microphone quality, captured duration, permission denial/recovery, countdown cancellation, restart pose recovery, background handling, network failures and temp-file cleanup. Require annotated student/device trials for filler precision/recall, Bisaya/code-switch Whisper behavior, retained hesitations, pace reliability, posture geometry/visibility, framing hysteresis, RMS labels and scoring validity. Unit tests using synthetic points/transcripts are not model-accuracy evidence.

### Existing documents that need correction

| Document/UI | Current mismatch |
| --- | --- |
| `README.md` | Calls speech/posture/fillers/transcript/internet simulated, denies uploads, recommends unconfigured run/web commands; source now has real cloud/audio/pose integrations and Android constraints. |
| `docs/SYSTEM_OVERVIEW.md` | Older “all simulated” architecture/permissions/scoring, four speech types, max camera preset/audio flag, and missing-cloud statements are no longer accurate. It includes demo credential examples that should not be copied forward. |
| `docs/data_dictionary.md` | Omits source document name, reference/comparison/valid-pose fields, transcript offsets, optional Impromptu profile link; states count equals detectedTimes length rather than current offsets-or-times rule. |
| `docs/script_comparison.md` | Earlier flow omits Device Check and refers to simulated posture; current implementation differs. |
| `docs/live_filler_transcription.md`, `ambient_noise_readiness.md`, `responsiveness_review.md` | Useful feature-specific notes, but earlier successful test counts/build claims are historical and do not reflect current compile failure. |
| Settings Privacy Details | Denies cloud uploads despite Groq audio transfer. |
| Settings Help / About | Help emphasizes demo controls; About says no real AI analysis despite Whisper and Pose integration. |
| Settings camera-attention text / report camera score | Promises looking-away behavior and shows a percentage without actual face/camera-facing analysis. |
| Earlier proposed model diagrams | Must use current type IDs 0/1/2/3/4/5, field names/nullability, optional Impromptu profile, real reference/offset/comparison/pose fields. Do not label preferences merely planned: they are registered and persisted. |

No complete current capstone manuscript, approved scoring rubric, acceptance criteria, UML source, or validated dataset was supplied in this audit. Alignment is therefore based on the requested feature topics, inspected project documentation and actual code; it cannot certify conformity to an unseen final capstone document.

### Areas not verified

This audit did not verify the installed phone APK's version/configuration, perform live Groq requests, inspect provider account limits/retention, run actual microphone/camera/MediaPipe inference, benchmark native FPS/thermal use, install a fresh Android artifact, validate production signing, submit to a store, or build iOS/web. Secrets, real stored student records, and personal recording contents were not copied into the report. The existing APK and cached Android manifest are historical artifacts only. Re-run this audit's checks after the compiler repair and before making operational or accuracy claims.
