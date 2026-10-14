# Feature #4: Prepared / Persuasive Script Comparison

## Flow and scope

Practice Setup → select PDF/DOCX/TXT → camera preview → I'm Ready → 3–2–1 → rehearsal → existing Groq Whisper transcript → report.

Prepared and Persuasive require a reference document. The selected name, Replace document, Remove document, and editable extracted text appear in the existing setup card. Cancelling selection or failing to replace a document preserves the previous selection. Impromptu has no upload or comparison section.

Comparison is deterministic script-adherence analysis. It does not grade facts, grammar, vocabulary, organization, persuasiveness, pronunciation, emotions, confidence, or engagement. No second Whisper request or other AI model is used. WPM, filler detection, simulated posture/camera, and overall scoring are unchanged.

## Local document extraction

- PDF: `pdfrx` (resolved 2.4.7) packages PDFium on Android. Open the selected bytes locally, read each page's text layer, and dispose the document. There is no upload or OCR. No-text/scanned, unreadable, damaged, and protected PDFs show an explanatory error.
- DOCX: reuse `archive` to read `word/document.xml`; `xml` (7.0.1, previously transitive) reads text runs, paragraphs, line breaks, tabs, and character entities. This parsing runs off the UI isolate on Android.
- TXT: decode UTF-8 with a Latin-1 fallback, strip the UTF-8 BOM, normalize line endings/spacing. Extraction runs off the UI isolate on Android.
- File limits: 10 MB, PDFs up to 100 pages, DOCX XML body up to 4 MB, extracted script up to 120,000 characters. Oversized input produces a message, not a silently truncated script.

Package documentation: [pdfrx](https://pub.dev/packages/pdfrx/versions/2.4.7), [xml](https://pub.dev/packages/xml/versions/7.0.1). PDFium support adds native dependencies to the APK; perform a full rebuild after pulling these changes.

## Word comparison and coverage

The service lowercases Unicode word tokens, ignores extra whitespace and punctuation, and normalizes curly/modifier apostrophes to straight apostrophes inside words. Filipino/Bisaya letters and contractions such as `mura'g` are preserved.

An order-sensitive longest common subsequence (LCS) aligns words, including repeated occurrences. Consecutive differences become readable phrases:

- Reference-only gap: Omitted Portions.
- Transcript-only gap: Added Portions.
- Both sides changed between matching anchors: Different Wording, shown as Expected and Spoken. This is a positional replacement heuristic, not a semantic judgment.
- Consecutive aligned words: matched portions.

`Script Coverage = matched reference words / total reference words × 100`.

Added words can coexist with 100% coverage; the added-phrases list still shows them. Coverage is separate from the overall score. Missing transcripts are unavailable, not 0% coverage or a full match.

Identical prefixes and suffixes are stripped before building the LCS table. The remaining table is limited to 8,000,000 cells, and either text is limited to 120,000 characters. More costly comparisons return a clear unavailable result without blocking the rest of the report. Rehearsal comparison runs in a background isolate on Android. Old saved reports without comparison totals are recomputed from their stored texts with the same bounds.

## Persistence and compatibility

Reuse `SpeechProfile.speechContent` (Hive field 6) and its existing filename field. The existing `PerformanceReport.referenceScript` and filename fields preserve the rehearsal snapshot. Existing lists at fields 19–21 store omitted, added, and Expected/Spoken phrases.

Append only these nullable fields to PerformanceReport:

| Hive index | Field | Type |
| --- | --- | --- |
| 22 | totalScriptWords | int? |
| 23 | matchedScriptWords | int? |
| 24 | scriptComparisonStatus | String? |

The existing type ID and fields 0–21 are unchanged. The adapter was regenerated. Older records read null for the new fields. Coverage is derived from counts rather than duplicated as another stored percentage. `PracticeSession` carries these values between report UI and repository. The existing session/report IDs and duplicate-save guard are reused.

Performance Report and Progress → Session Details use the same comparison summary. Missing transcripts retain the script and show an unavailable explanation. Impromptu suppresses comparison even if stale script data exists.

## Android manual test

1. Rebuild/run with `flutter run -d A8UVB21C28001776 --dart-define-from-file=.env.json` (do not commit `.env.json`).
2. Select Prepared, language, and duration. Without a document, Continue must show validation.
3. Upload a text-based PDF, DOCX, or TXT. Verify filename/text, replace it, remove it, and choose again. Try an empty TXT, damaged DOCX/PDF, and scanned PDF: show an error without crashing.
4. Use reference: `We value effective clear communication today`.
5. Wait in the preview; confirm nothing records before I'm Ready and the full countdown.
6. Say `We value communication today`, then end. If Whisper returns those words, expect 4/6 words and 66.7% coverage, with `effective clear` omitted.
7. For additions, say `We value effective clear communication in our school today`. All reference words match; coverage is 100%, with `in our school` added.
8. For replacement, change `effective clear` to `meaningful honest`; look for Expected/Spoken wording. Whisper output—not the raw audio—is the comparison input.
9. Save, reopen through Progress → Session Details, and relaunch the app. Counts, phrases, and filename should remain, without duplicate session entries.
10. Repeat with Persuasive. Use Impromptu to confirm no upload/comparison appears and transcript, WPM, and filler feedback remain.
11. Try a transcription failure: the rest of the report still opens, with comparison unavailable rather than a misleading match.

## Automated verification

`dart format .`, `flutter analyze`, `flutter test`.

Tests cover exact/omitted/added/replaced wording, punctuation/case, localized apostrophes and letters, repeated words, empty texts, long texts, actual PDF/DOCX/TXT extraction, document errors, old Hive fields, save/reopen/duplicate protection, unavailable states, and Impromptu suppression. The existing countdown, WPM, filler, and microphone regression tests remain.

## Changed files

- `lib/services/script_comparison_service.dart` — bounded Unicode word-level LCS, grouped differences, counts, and availability.
- `lib/services/speech_document_service.dart` — local PDF/DOCX/TXT extraction, limits, and errors.
- `lib/models/performance_report.dart` and `lib/models/performance_report.g.dart` — appended nullable fields 22–24 and regenerated adapter.
- `lib/models/practice_session.dart` — comparison values for UI/persistence, legacy fallback, and Impromptu eligibility.
- `lib/storage/hive_repository.dart` — round-trip comparison values and exclude Impromptu script linkage.
- `lib/screens/practice_flow.dart` — replace-file action, expanded file support, background comparison using the existing transcript, and result display.
- `lib/screens/progress_screens.dart` — same comparison result in saved Session Details.
- `lib/widgets/common_widgets.dart` — shared coverage/difference/unavailable cards.
- `pubspec.yaml` and `pubspec.lock` — PDF extraction dependencies and explicit XML dependency.
- `test/script_comparison_service_test.dart` — deterministic comparison cases.
- `test/speech_document_service_test.dart` — actual extraction and error cases.
- `test/script_comparison_report_test.dart` — Hive compatibility, persistence, and report UI.
- `docs/script_comparison.md` — this implementation and testing guide.
