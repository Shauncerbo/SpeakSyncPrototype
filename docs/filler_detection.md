# Transcript filler detection

The Performance Report and saved Session Details use the existing Groq
Whisper transcript. Loaded sessions receive `PerformanceReport.textTranscript`;
new sessions use that same transcript before saving. Reference scripts and
simulated live transcript lines are not used for detection.

The matcher lowercases text, treats punctuation as word boundaries, and matches
whole tokens. It counts `um`, `uhm`, `ah`, `ano`, `parang`, `kasi`, `kuan`,
`kanang`, `bitaw`, and `mura'g` separately. Repeated-ending forms such as `umm`,
`uhmm`, and `ahhh` are grouped with their base forms; `kwan` maps to `kuan`;
`murag` and curly-apostrophe `mura’g` map to `mura'g`.

Frequency = total occurrences / actual session duration in minutes.
Fractional rates use continuous bands without rounding before classification:

| Fillers/minute | Interpretation |
| --- | --- |
| 0 to less than 2 | Very Low |
| 2 to less than 6 | Low / Acceptable |
| 6 to less than 12 | Elevated |
| 12 and above | High |

A valid transcript without fillers gives zero and Very Low. Missing/empty text
gives Not available. Zero duration preserves detected counts but leaves the rate
unavailable. This does not calculate a final 0–100 filler score. WPM and the
existing simulated scores are unchanged.

## Storage

`PerformanceReport.fillerCounts` stores canonical word/count pairs. One
`FillerWordLog` per word/session stores the count and `transcriptOffsets`:
zero-based Dart string positions in the lowercased, apostrophe-normalized text.
Hive field 5 is new and defaults to an empty list for older logs. Existing field
indices and type IDs are unchanged. These positions are not audio timestamps.
New logs leave `detectedTimes` empty because the current Whisper response supplies
text only. Old timestamp-based logs remain readable.

Stable IDs and the existing completed-session guard prevent duplicate logs on
repeated saves. Summary and logs are built from the same detection result.

## Manual phone test

1. Run `flutter run -d A8UVB21C28001776 --dart-define-from-file=.env.json`.
2. Rehearse for one minute, including the ten listed expressions once each.
3. Inspect the returned Text transcript first: only words actually returned by
   Whisper can be counted. It may omit spoken hesitations.
4. If all ten appear once and duration is 60 seconds, expect total 10,
   10.0 fillers/min, Elevated, and ten separate entries of 1.
5. Save the report, restart the app, and reopen the session in Progress.
6. Save the same session again: neither history nor filler logs should duplicate.
7. Try a transcript without listed words: expect 0 and Very Low. A missing
   transcript should show Not available, not a misleading perfect result.

These are dictionary matches. Words such as `kasi` and `parang` can be meaningful
in context; the prototype does not distinguish those uses from hesitations.
