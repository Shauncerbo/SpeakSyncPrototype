# Phase 2A: Nullable performance results

Date: October 10, 2026. This document supplements the historical
`SPEAKSYNC_SYSTEM_AUDIT.md`; it does not change that audit's original findings.

## Storage contract

`PerformanceReport` retains Hive type ID **5**, every existing field index,
and its 26-field adapter layout. No box names, other type IDs, or record IDs
have changed. No score formula or Face Landmarker has been implemented.

| Existing index | Field | New type | Meaning for a newly saved rehearsal |
| --- | --- | --- | --- |
| 3 | wordsPerMinute | double? | Complete-transcript word count divided by actual session minutes; null without recognized words or positive duration. |
| 4 | paceScore | int? | Null: a validated 0–100 pace score is not implemented. |
| 5 | fillerScore | int? | Null: a validated 0–100 filler score is not implemented. |
| 6 | goodPostureSeconds | int? | Actual tracked acceptable-pose time when results are available; otherwise null, never estimated from an old score. |
| 7 | postureScore | int? | Existing pose-derived acceptable-time percentage when at least three seconds of valid pose coverage exist; otherwise null. This is not a validated educational score. |
| 8 | cameraFacingSeconds | int? | Null: camera-facing attention is not measured. |
| 9 | cameraScore | int? | Null: camera-facing attention is not measured. |
| 10 | overallScore | int? | Null: a validated overall scoring policy is not implemented. |

`validPostureSeconds` remains nullable at index 25. Missing coverage in legacy
reports is not inferred from their numeric posture score. An actual measured
posture percentage of **0** with sufficient coverage is retained and displayed
as **0%**; null/insufficient coverage is displayed as unavailable. Valid coverage
and actual acceptable time are retained separately. The three-second minimum
matches the existing default pose summary threshold; changing that configurable
threshold later will require updating the storage availability contract too.

Recognized word counts, actual available WPM, transcript-derived filler counts
and logs, transcripts, scripts, comparison outputs, and tracked posture remain
in their existing fields. Zero recognized words and an empty filler map remain
valid counts, not fabricated performance scores. Camera framing is unchanged;
it is pose-based feedback, not Face Landmarker attention.

## New saves and presentation

- The rehearsal screen no longer calculates prototype pace, filler, attention,
  or overall scores. Missing pose results no longer become zero percentages.
- `HiveRepository.saveCompletedRehearsal` ignores legacy/manual score inputs for
  unvalidated categories and persists null. New sessions mark camera-attention
  monitoring inactive, even if an old setup preference was enabled.
- Direct `savePerformanceReport` calls accept nulls, reject unvalidated score
  fields/non-null camera-facing time, reject invalid numeric ranges/non-finite
  WPM, and require sufficient valid coverage for non-null posture results.
- History loading preserves raw legacy numbers in the data model, but those
  numbers do not establish validity. `validatedOverallScore` and
  `measuredAttentionPercentage` remain unavailable. No new validity flag or
  arbitrary score replacement has been added.
- Reports, history, home summaries, progress averages/trends/improvement, and
  rankings consume availability-aware properties. There are no validated
  overall scores yet, so scoring/rankings remain unavailable. Session lists,
  counts, practice duration, and actual available measurements still work.
- Coaching uses available final transcript/pose measurements, not stored legacy
  score-dependent claims about perfect scores or eye contact.
- Previously removed student-facing simulation buttons and corrected privacy
  disclosures remain in place. Authentication is unchanged.

## Upgrade and downgrade compatibility

The new adapter accepts older integer scores and double WPM. Existing reports
are **not automatically migrated, sanitized, deleted, or overwritten**. Old
numbers remain legacy values. Reading them and attempting the normal duplicate
session save does not rewrite them. Existing explicit user deletion/reset
actions remain unchanged; this phase does not invoke them.

Regression fixtures cover actual old 17-field numeric Hive bytes, old-style
26-field numeric records including measured posture coverage, and new nullable
records. The 17-field fixture's report file is compared byte-for-byte before
and after reopening/reading and a rejected duplicate save. This does not claim
that every APK/database variant ever distributed was tested.

**Downgrade limitation:** earlier APKs whose generated adapters cast indexes
3–10 to non-nullable numbers cannot read newly saved null values. A strict
old-adapter regression confirms the type-cast failure. Therefore do not install
an incompatible older APK against this updated database. Keep a backup made
before upgrading if an older build may be needed, or use a future compatible
reader/export path. No downgrade conversion, automatic backup, reset, or data
deletion has been performed. Uninstalling the app may remove its local data.

## Regression coverage and remaining verification

The changed/new tests cover nullable Hive round trips, numeric legacy reads,
no automatic rewriting, measured-zero versus unavailable posture, no fabricated
durations, null WPM for missing/empty/punctuation-only transcripts or zero
duration, validation guards, real filler/WPM preservation, UI null handling,
legacy-score exclusion, and script-comparison persistence.

Device installation, real Groq requests, MediaPipe accuracy/calibration, and
upgrade testing against an actual phone database are not established by these
automated tests. Face Landmarker and validated scoring are deliberately still
planned. The Hive generator also warns that its analyzer dependency supports an
older language version than the installed Dart SDK; adapter generation itself
succeeded. Dependency upgrades are outside this phase.

## Files changed in this nullable-fields update

| File | Change |
| --- | --- |
| `lib/models/performance_report.dart` | Nullable existing measurements/scores; field IDs unchanged. |
| `lib/models/performance_report.g.dart` | Regenerated nullable casts; type ID 5 and indexes 0–25 unchanged. |
| `lib/models/practice_session.dart` | Nullable runtime scores and explicit unavailable-posture handling. |
| `lib/screens/practice_flow.dart` | Remove prototype calculations/state and produce null unmeasured results. |
| `lib/screens/progress_screens.dart` | Rankings consume availability-aware results, never raw legacy scores. |
| `lib/widgets/common_widgets.dart` | Chart filters/plots only validated results. |
| `lib/storage/hive_repository.dart` | Null-aware saving/validation; remove inferred pose/camera time; preserve old reads. |
| `test/hive_repository_test.dart` | New-save null expectations and preserved real measurements. |
| `test/script_comparison_report_test.dart` | Comparison persistence remains valid without an overall score. |
| `test/scoring_integrity_test.dart` | Nullable UI results and measured-zero/unavailable posture regressions. |
| `test/nullable_performance_storage_test.dart` | New compatibility, round-trip, no-rewrite, validation and availability tests. |
| `docs/phase_2a_nullable_results.md` | Storage contract, compatibility limitation, verification and handoff. |

Earlier Phase 2A UI/privacy changes in other files were preserved, not reapplied
or counted as new edits in this update. Existing unrelated working-tree changes
were not reverted.

## Completed validation

| Check | Observed result |
| --- | --- |
| `dart format` on the 11 modified/new Dart files | Passed; final run reported zero remaining formatting changes. |
| `flutter analyze --no-pub` | Passed: no issues found. |
| `flutter test --no-pub --reporter expanded` | Passed: 513 passed, 2 skipped (existing Groq-configuration gates). |
| The two gated readiness/lifecycle tests, separately with `GROQ_API_KEY=test-placeholder` and mocked services | Passed: 2 passed. No real API credential or cloud request was needed. |
| `flutter build apk --debug --dart-define-from-file=.env.json --no-pub` | Passed: fresh debug APK generated; Gradle reported 19.8 seconds. |

APK: `build/app/outputs/flutter-apk/app-debug.apk`, 223,413,383 bytes, generated
October 10, 2026 at 18:19:10 local workspace time. Build output was redacted;
credentials were neither inserted into source nor documented here.

There are no remaining analysis, regression-test, or debug-build errors in
these verification runs. The warning from deliberate adapter replacement in
the legacy-wire fixture is expected and test-only; production registration is
unchanged. The generator dependency-version warning remains as noted above.

## Android handoff

1. Preserve/backup existing local data before upgrading; do not uninstall or
   use Reset Prototype Data to install this update.
2. Verify existing history entries still exist and no old overall/attention
   numbers are displayed as measurements or used in rankings/coaching.
3. Save a new rehearsal: real transcript, WPM, fillers and script comparison
   should remain available when transcription succeeds, while unvalidated
   scores and attention remain unavailable.
4. Compare a rehearsal with insufficient visible pose coverage against a
   sufficiently sampled rehearsal with zero acceptable-pose time. Only the
   latter should show a measured 0% posture result.
5. Force-close/reopen the updated app and verify saved results remain intact.
   Do not downgrade to an old strict-adapter APK against the new database.

The Phase 2A implementation and automated validation are complete; physical
phone upgrade/measurement verification remains pending. Recommended next work
is device upgrade testing and pose/framing calibration, followed by separately
approved scoring-policy and Face Landmarker phases. No such phase was begun.
