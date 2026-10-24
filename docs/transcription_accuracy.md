# Code-switched transcription: first configuration phase

This update enables a model/context comparison. It does **not** establish an
accuracy improvement for English, Filipino, or Cebuano/Bisaya speech.

## Inspected pipeline and unchanged behavior

- With live speech feedback enabled, the recorder captures mono 16 kHz PCM16
  once. Ten seconds of new audio plus the configured boundary overlap feed one
  live Groq request per cadence;
  the same result supplies the existing filler detector and smoothed live pace.
  The entire PCM capture is wrapped as WAV for the separate final request.
- With live feedback off (or PCM capture unavailable), the existing full mono
  16 kHz AAC/M4A recording path remains. No live requests are created when live
  feedback is off. Recording, durations, permission handling and cleanup are not
  changed by this phase.
- The final transcript alone feeds final WPM, filler counts, script comparison,
  coaching and Hive reports. No partial transcripts or comparison outputs are
  merged into the final transcript. No scoring or camera logic changes.

## Build configuration

Keep the existing key in the ignored local `.env.json`, not Dart source or a
committed file. `.env.json.example` includes the additional non-secret settings:

| Setting | Default | Effect |
| --- | --- | --- |
| `GROQ_FINAL_TRANSCRIPTION_MODEL` | `whisper-large-v3` | Final full-recording model. Set `whisper-large-v3-turbo` to revert. Unknown or empty IDs conservatively resolve to Turbo. |
| `GROQ_TRANSCRIPTION_CONTEXT_ENABLED` | `true` | Include a short code-switching/spelling context in live and final requests. Set JSON boolean `false` to omit it entirely. |

These are Dart compile-time defines: rebuild/restart, not hot reload, after
changing them. Existing `.env.json` files containing only the API key work with
the defaults; the implementation does not edit the local key file.

```powershell
flutter run -d A8UVB21C28001776 --dart-define-from-file=.env.json
```

For a temporary final-model rollback without editing the local configuration:

```powershell
flutter run -d A8UVB21C28001776 --dart-define-from-file=.env.json --dart-define=GROQ_FINAL_TRANSCRIPTION_MODEL=whisper-large-v3-turbo
```

Live model selection is fixed to Turbo, including after a final-model change.
One rehearsal sends **one** final request, not a model comparison or automatic
fallback retry. Large V3 may have different latency, availability, cost and rate
limits. Failures follow the existing unavailable-transcript flow; choose Turbo
explicitly for a later run if needed. Existing live/final timeouts remain eight
and ninety seconds respectively.

Both models use `/audio/transcriptions`, JSON output and explicit temperature
`0`. The `language` field is omitted for all rehearsal modes, allowing automatic
recognition rather than forcing English or one language across mixed speech.
There is no translation request or translation/post-correction stage.

The concise context describes English, Filipino/Tagalog and Cebuano/Bisaya
public-speaking rehearsals with spellings such as ano, parang, kasi, kuan,
ku'an, kanang, mura'g and bitaw. It contains no student script, prior partial
transcript, identity or personal information. Returned text is only trimmed at
its boundaries, never supplemented from the context or lexicon. Empty results
remain unavailable rather than being replaced with example words.

**Important:** Whisper context is not an enforceable instruction. Temperature
zero, the transcription endpoint and context wording do not guarantee faithful
code-switching, filler preservation or absence of hallucinations. The client
does not detect or remove model-inserted example words; doing so could erase
genuinely spoken words. Assess those errors against the original audio.

## Controlled before/after evaluation (not performed by these unit tests)

The reproducible Step 4 harness, private-data manifest, normalization policy,
CSV schema, consent gates, and execution instructions are documented in
[`evaluation/README.md`](../evaluation/README.md). The harness supports all four
model/context combinations described below and is offline by default.

1. Obtain consented, researcher-controlled audio fixtures and manually verified
   verbatim transcripts. Include monolingual and code-switched speech, local
   fillers, meaningful uses of dictionary words, filler-free speech, pauses,
   silence and varied recording conditions. Do not commit these fixtures.
2. Compare **identical audio bytes**, not two different readings. In a private
   evaluation harness or Groq's transcription tools, use the existing
   `GroqTranscriptionService.finalRecording` with an explicit `model` and
   `enableContextPrompt`. Compare Turbo/no-context, V3/no-context,
   Turbo/context and V3/context. Keep temperature, audio and all other settings
   constant. The app deliberately does not retain production recordings for
   this comparison; use separately collected fixtures rather than disabling
   normal cleanup.
3. The earlier app used Turbo with its older filler-aware context for final
   requests and no context for live requests. Neither new configuration is an
   exact replica of that old prompt. For a strict historical baseline, record
   its original prompt/configuration separately instead of labelling the new
   Turbo/context condition as unchanged historical behavior.
4. Measure word error rate `(substitutions + deletions + insertions) / reference
   word count` using one documented normalization policy. Separately inspect
   language preservation, omitted/inserted fillers, filler precision/recall,
   latency, request failures and cost. Evaluate silent clips by inserted words;
   word error rate has no meaningful denominator for an empty reference.
5. Keep transcripts and audio private. Store configuration/model names with
   evaluation results outside student Hive records. Do not log API keys, audio
   bytes or student transcripts. After review, select/revert the final model and
   context flag, rebuild, and repeat Android end-to-end smoke tests.

## Android smoke check

Try a consented mixed-language practice with live feedback ON, then OFF. Check
ten-second live filler/pace feedback when enabled and the complete final
transcript, WPM, filler counts, script comparison and saved/reopened report.
Repeat with final Turbo selected and context disabled to verify the switches.
These checks demonstrate behavior, not recognition accuracy.

## Verification scope and privacy

Mocked request tests check model selection, temperature, omitted language field,
optional context, mixed-language text preservation, no client-inserted fillers,
empty results, single shared live requests, and safe API errors. They do not
send real audio to Groq or measure recognition quality. API errors expose only
HTTP status, not potentially sensitive provider response bodies. No new debug
logging is added. Existing APK-embedded API-key security limitations remain.

API reference: [Groq Speech to Text](https://console.groq.com/docs/speech-to-text).
Groq documents multilingual V3/Turbo, temperature zero and optional contextual
prompting; this is not evidence of accuracy on SpeakSync's target student data.
