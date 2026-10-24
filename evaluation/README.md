# SpeakSync transcription accuracy evaluation

This framework compares transcripts generated from the **same consented audio**
against a manually verified verbatim reference. It does not contain measured
accuracy results, participant data, or audio. Files under `fixtures/` are
synthetic calculation examples only.

## Prepare private evaluation data

1. Copy `manifest.template.json` to `manifest.json`.
2. Put consented audio and transcripts under `evaluation/private/`. This folder
   is ignored by Git. Use anonymous recording IDs; do not use student names.
3. Prepare the reference while listening to the exact evaluation recording:
   - transcribe every spoken word in its original English, Filipino, or
     Cebuano/Bisaya language;
   - retain audible `um`, `uhm`, `ah`, `ano`, `parang`, `kasi`, `kuan`,
     `kanang`, `mura'g`, and `bitaw`, including legitimate non-hesitation uses;
   - count naturally repeated fillers separately;
   - do not correct grammar, translate, or add intended-but-unspoken words;
   - have a second reviewer compare the reference with the audio and resolve
     disagreements before evaluating models.
   Set `referenceVerified` to `true` only after this review, and label the
   sample's `languageGroup` as `english`, `filipino`, `cebuano_bisaya`, or
   `code_switched` so results can be grouped without participant identity.
4. Record the app's rehearsal duration in `rehearsalDurationSeconds`. Measure
   the retained audio separately as `audioDurationSeconds`. The evaluator uses
   rehearsal duration for WPM, matching SpeakSync's existing methodology, and
   reports the difference without silently correcting it.
5. Record conditions consistently: quiet/noisy, normal/soft volume, built-in/
   wired/Bluetooth microphone, boundary speech, and interruption notes.

### Recording-interruption validity check

The current app calculates final WPM with its rehearsal timer. A manual
microphone disable or an Android audio interruption can pause captured audio
while that timer continues. Conversely, the end-session confirmation pauses
the timer before the recorder is stopped, so retained audio can be longer.
For every evaluated sample, measure the decoded audio duration independently
and compare it with `rehearsalDurationSeconds`. The CSV reports their signed
difference. Treat a material mismatch as a validity flag and report it; do not
silently substitute audio duration because that would change the established
SpeakSync WPM methodology.

Normalization ignores capitalization and punctuation, collapses whitespace,
standardizes apostrophes, and canonicalizes only supported spelling variants:
`kwan` and `ku'an` become `kuan`; `mura'g` becomes `murag`; lengthened supported
`um`, `uhm`, and `ah` spellings use their canonical forms. It does not remove
fillers or erase other language/spelling differences. CER is calculated over
the resulting normalized text, including its single spaces.

## Offline evaluation (no upload)

Create the four hypothesis transcript files listed in the manifest, then run:

```powershell
dart run tool/transcription_accuracy_evaluation.dart `
  --manifest evaluation/manifest.json `
  --output evaluation/results.csv
```

This mode reads text files only and makes no network request. Missing files and
metrics appear explicitly in the CSV as statuses or `NA`.

To smoke-test the harness using non-audio synthetic text fixtures:

```powershell
dart run tool/transcription_accuracy_evaluation.dart `
  --manifest evaluation/synthetic_manifest.json `
  --output evaluation/results_synthetic.csv
```

The resulting numbers validate calculations only and are not recognition
accuracy measurements because every configuration uses prepared text.

## Authorized API comparison

API mode uploads each consented recording four times: Turbo context OFF/ON and
Large V3 context OFF/ON. It therefore has cost, rate-limit, and privacy impact.
Every manifest recording must have `consentConfirmed: true`, both authorization
flags are required, and `referenceVerified: true` must confirm manual review.
The key must be supplied through the process environment. It is never printed
or written to the report.

```powershell
$env:GROQ_API_KEY = (Get-Content .env.json | ConvertFrom-Json).GROQ_API_KEY
dart run tool/transcription_accuracy_evaluation.dart `
  --manifest evaluation/manifest.json `
  --output evaluation/results.csv `
  --run-api --authorize-paid-api
Remove-Item Env:GROQ_API_KEY
```

The CSV contains metrics and condition metadata, not raw audio or transcript
text. Securely retain source material separately if researchers need error
review. Do not commit private recordings, transcripts, or participant IDs.

## Interpreting results

- WER = word edit distance / reference word count.
- CER = character edit distance / normalized reference character count.
- Filler correct/missed/incorrect use word-sequence alignment and canonical
  expressions, so an occurrence inserted at another location is not credited
  merely because totals match. This is lexical occurrence evaluation, not
  semantic hesitation classification.
- Precision, recall, and F1 use aggregate filler occurrences.
- WPM error compares recognized word count with verified reference word count
  using the same rehearsal duration.
- Latency measures one complete request, not network-independent model time.
- `audio_minus_rehearsal_seconds` exposes possible interruption or duration
  mismatch. Researchers must review it; the harness does not change scoring.

Use multiple repetitions per condition and report distributions, failures, and
sample counts. Never describe synthetic fixtures as accuracy evidence.
