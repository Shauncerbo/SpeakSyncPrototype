# Phase 4A: Measurement-based coaching and feedback

Date: October 15, 2026 (Asia/Manila).

This supplements the historical `SPEAKSYNC_SYSTEM_AUDIT.md`. Phase 4B,
authentication changes, Face/Pose detector redesigns, and pace/filler/overall
score formulas are outside this implementation and were not started.

## Reference and approval scope

The workspace contains the historical audit, Phase 2A/3 notes, filler-detection
documentation, and source code. A separate approved capstone methodology
document was not found. Implementation uses the Phase 4A request's thresholds
and existing documented rules; no claim of expert validation is made.

The existing fractional filler-rate interpretation is preserved: `[0,2)` Very
Low, `[2,6)` Low / Acceptable, `[6,12)` Elevated, `[12,infinity)` High. This is
the continuous interpretation already documented in `docs/filler_detection.md`
for the integer-labelled bands 0–1, 2–5, 6–11, and 12+. Rates are not rounded
before classification. Researcher confirmation of this convention is still
needed if the formal methodology instead requires rounding.

## Implementation

`MeasurementCoaching.generate` produces deterministic, student-readable advice
from the same final measurements used in reports. It does not call another AI
API, use live chunk totals, invent a grading formula, or read legacy stored
coaching strings as evidence.

| Area | Evidence and behavior |
| --- | --- |
| Speaking pace | Final `textTranscript` word count / actual session minutes, using existing `SpeakingPace`. Below 120 Slow, 120–160 Target / Effective, above 160 Fast. Each gets a practical recommendation; missing text/invalid duration stays unavailable. |
| Fillers | Existing `FillerAnalysis` and lexicon, using final transcript counts and actual duration. Shows total, frequency/category, and up to three most frequent expressions sorted by count (alphabetically for ties). Advice explicitly says dictionary matches may be meaningful words, not necessarily hesitations. Missing text is not a claimed zero; zero duration preserves recognized matches without a frequency. |
| Posture | Existing genuine acceptable-time percentage and at least three valid analysis seconds, consistent with Phase 2A. Missing coverage/range-invalid values/demos/disabled monitoring are unavailable. A measured 0% can produce adjustment advice; unavailable data cannot. Existing `postureScore` is a legacy field name for this time fraction, not a newly introduced educational score. |
| Head direction | Existing Face measurement provenance: valid coverage >= 3000 ms, valid facing time and percentage. Below 100% receives consistency advice; available rounded results are described as estimates. Missing data is not poor performance. No claim of eye contact or audience engagement. |
| Framing | Existing Too Close/Proper/Too Far classifications are accumulated over adjacent valid analysis intervals. Advice says move farther/closer when those classifications were actually measured. Missing coverage is Unavailable. This is separate from head-direction feedback. |

`CameraFramingSummaryTracker` adds small duration counters to the existing
camera callback. It uses the existing Pose `maximumSampleGap` (default 700 ms),
attributes an interval to the preceding valid classification, and excludes
missing frames, interruptions, long gaps, and non-increasing timestamps.
It starts with actual rehearsal monitoring, not preparation/countdown; restart
clears its counters. Stop/interruption preserves totals but breaks continuity.
It adds no inference request, new distance threshold, or raw frame storage.

Existing percentage rounding and whole-second Pose/facing counters are retained.
Coaching avoids claiming an exact all-session performance from rounded values
or treating unobserved intervals as poor performance. Framing milliseconds do
not imply that the camera was analysed continuously.

## Report and history consistency

- `PracticeSession.measuredCoachingTipsFor` delegates to the new service.
- Its four runtime monitoring flags are set from Practice Setup and restored
  from existing `RehearsalSession` fields on history loading.
- Enabled-but-unavailable monitoring stays distinct from disabled monitoring.
- `HiveRepository` generates saved coaching from final measurements and saved
  monitoring choices, not temporary live results or old numeric grades.
- New saves keep unvalidated pace/filler/overall scores null. Disabled visual
  monitoring does not save misleading posture/face/framing results.
- Word counts, WPM and dictionary counts remain available in storage from the
  final transcript even when speech monitoring is disabled; display/advice are
  correctly marked off. Transcription and script comparison are unaffected.
- Reports and Session Details replace the fixed “Recommended posture” text
  with availability-aware “Upper-body feedback”. The legacy string property
  remains for compatibility, but is not rendered as genuine advice.
- Home/Progress already consume `measuredCoachingTips`, so their coaching focus
  now uses this service too. No score-based ranking formula was added.
- Demo IDs (`initial-*`) receive an example notice, not measured coaching.
- Old scores without measurement provenance remain legacy values; stored tips
  are not trusted. Reading a historical record does not rewrite it.

## Storage compatibility

`PerformanceReport` retains Hive type ID **5** and existing field indexes
**0–26**. One optional field is appended:

| Index | Field | Type | Meaning |
| --- | --- | --- | --- |
| 27 | cameraFramingMilliseconds | Map<String, int>? | Valid milliseconds under keys `tooClose`, `proper`, `tooFar`. Null for older/disabled records; zero totals mean no valid framing interval. |

The adapter is regenerated and writes 28 fields. Existing numeric and nullable
records without field 27 read it as null. Negative durations or unknown framing
keys are rejected on new writes. Runtime history maps are read-only snapshots.
No record deletion, automatic historical overwrite, renumbering, or box/type-ID
change is performed.

Older nullable readers can ignore an unknown optional field when reading, but
an old APK rewriting a record may discard new fields. The existing Phase 2A
limitation remains: pre-nullable APK adapters cannot read newly saved null scores.
Do not downgrade against this database without a compatible reader or backup.
Uninstalling the application may delete its local data.

## Exact files changed

| File | Change |
| --- | --- |
| `lib/services/measurement_coaching.dart` (new) | Final-measurement advice, availability, category rules and contextual filler disclaimer. |
| `lib/services/camera_framing_summary.dart` (new) | Valid-time framing accumulation and reset/interruption handling. |
| `lib/models/practice_session.dart` | Monitoring flags, framing durations, coaching delegation, measured-result gates and posture feedback. |
| `lib/models/performance_report.dart` | Optional field 27, unchanged existing schema indexes. |
| `lib/models/performance_report.g.dart` | Regenerated compatible adapter. |
| `lib/storage/hive_repository.dart` | Save/load monitoring choices and framing, derive coaching, gate disabled results and validate metadata. |
| `lib/screens/practice_flow.dart` | Capture framing summary, preserve monitoring choices, derived report feedback/off states. Live warning algorithms/settings are preserved. |
| `lib/screens/progress_screens.dart` | Matching saved-details feedback and disabled-monitoring presentation. |
| `lib/widgets/speaking_pace_card.dart` | Explicit monitoring-off display without a pace verdict. |
| `lib/widgets/filler_frequency_card.dart` | Explicit monitoring-off display without a filler verdict. |
| `test/measurement_coaching_test.dart` (new) | 29 new classification, measurement, coverage, monitoring, demo, persistence and widget tests. |
| `test/nullable_performance_storage_test.dart` | Optional-field absence assertions and current disclaimer/explicit monitoring fixture. |
| `docs/data_dictionary.md` | Correct nullable report contract and appended framing field. |
| `SPEAKSYNC_SYSTEM_AUDIT.md` | Link to this supplement; original historical findings preserved. |
| `docs/phase_4a_measurement_coaching.md` (new) | Implementation, validation, compatibility and approval notes. |

## Observed verification

| Check | Result |
| --- | --- |
| Format all 12 modified/new Dart files | Passed; final run made 0 additional changes. |
| Regenerate only `performance_report.g.dart` with existing build_runner | Succeeded. Existing generator/analyzer language-version warning remains (3.4 vs SDK 3.11); dependencies were not upgraded. |
| `flutter analyze --no-pub` | Passed: no issues found (13.4 seconds). |
| `flutter test --no-pub --reporter expanded` | Passed: 605 tests passed, 2 configuration-gated tests skipped (64 seconds). |
| Two gated readiness/recording tests with dummy define and mocked services | Both passed; no real Groq requests. |
| `flutter build apk --debug --dart-define-from-file=.env.json --no-pub` | Passed (54.4 seconds); credentials redacted from output. |

APK: `build/app/outputs/flutter-apk/app-debug.apk`.

The full suite includes previous transcription, filler/WPM, script comparison,
Pose/Face/framing, warning overlays, operational notifications, readiness,
history and responsive-layout regressions. Tests verify algorithms and mocked
interfaces, not acoustic accuracy, native inference on a phone, or coaching's
educational effectiveness. No physical device was installed/tested in this run.

## Physical-phone checklist and researcher decisions

1. Rehearse normally, then compare transcript/word count/duration with final
   WPM and pace coaching. Live partial feedback is not the report input.
2. Include several listed expressions; check that only words Whisper retains
   are counted and that the frequent-expression list matches final counts.
3. Rehearse with upright/tilted posture and facing/turned head. Check valid
   coverage and advice; cover landmarks to confirm unavailable data is not
   scored as bad posture or attention.
4. Move closer/farther, then return to proper framing. Review separate framing
   suggestions; do not interpret them as gaze/eye contact.
5. Save, restart the app, reopen Session Details and compare advice/measurements.
6. Repeat with individual monitoring toggles off and with Live Feedback off.
   Final analysis works independently of live alerts; disabled areas stay off.
7. Use Prepared/Persuasive scripts to verify comparison feedback still appears.

Before making validated capstone claims, researchers/advisers should provide the
formal approved methodology for cross-checking, confirm fractional filler-rate
bands and displayed advice wording, calibrate existing Pose/Face/framing criteria
on representative Android devices, and validate the advice with target students.
Whisper can omit fillers; dictionary detection cannot distinguish hesitation
from meaningful language; rounded percentages and limited valid coverage are
not whole-session proof. No expert validation, eye-contact measurement,
confidence, concentration, engagement, or factual-content assessment is claimed.

Phase 4B remains pending explicit user approval.
