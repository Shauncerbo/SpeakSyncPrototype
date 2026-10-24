# Near-real-time transcript feedback

The rehearsal microphone is captured once. When Live feedback and either
Filler-word or Speaking-pace monitoring are selected,
`RehearsalAudioRecorder` streams mono 16 kHz PCM16 to a temporary raw file. It
emits a live request after each 10 seconds of newly captured audio. Starting
with the second request, the live WAV also carries the preceding 750 ms of PCM
as recognition context for speech that crosses the boundary. This does not add
requests: the cadence remains one request per 10 seconds. At the end, the
recorder wraps the full raw recording as WAV, with every captured sample stored
once and no overlap. The full recording is sent through the
existing Groq Whisper service for the final transcript, WPM, filler counts,
script comparison, and report. Without live feedback, the existing AAC/M4A
recording path remains in use.

Each completed live chunk is wrapped as a temporary WAV and passed to a second
instance of the existing `GroqTranscriptionService` with the same app API key.
The short live request times out after 8 seconds and asks for word timestamps in
the same response. Words whose timestamp midpoint is inside the carried-over
750 ms are excluded. The remaining transcript goes through `FillerAnalysis`'s
existing normalization and lexicon. Each newly spoken filler produces a short
overlay such as `Filler detected: kuan`. The same deduplicated transcript,
without another Groq request, also goes through the existing `SpeakingPace`
word counter. Recent WPM is novel recognized words divided by 10/60 minutes.
If a response omits word timestamps, exact repeated suffix/prefix text removal
is used as a conservative fallback for consecutive processed chunks.

Live pace ignores empty transcripts and chunks with fewer than four recognized
words. It displays the arithmetic mean of the latest three valid chunk WPM
values (or all available valid chunks until three exist). Below 120 WPM is
Slow, 120 through 160 is Target, and above 160 is Fast. A failed or insufficient
chunk leaves the previous valid indicator unchanged. Partial transcripts,
live pace values, and live filler results are never saved in the report.

Live requests remain on `whisper-large-v3-turbo`. The final full-recording
request defaults to `whisper-large-v3`, configurable back to Turbo without
changing the live model. Both use explicit temperature 0 and automatic language
detection at the transcription endpoint, not the English translation endpoint.
An optional, concise English-Filipino-Cebuano context prompt supplies localized
spellings to both request types. The prompt is only a recognition hint, not a
list of words to insert. Neither client path appends context words or edits the
returned transcript. Model omissions, translations, or hallucinations can still
occur and require evaluation. The final filler frequency is still calculated
only from the complete final transcript; live detections are not added to it.

See [transcription configuration and evaluation](transcription_accuracy.md) for
build settings, rollback, and a controlled model/prompt comparison procedure.

Only one live request runs at a time, with at most one newer chunk buffered.
The newest replaces an older pending chunk if the API falls behind. Skipped
sequence numbers are not compared by the text fallback, preventing stale text
from being matched against unrelated later speech. Carried-over timestamped
words and consecutive identical normalized fallback transcripts do not alert
twice. A naturally repeated filler after the overlap boundary remains a new
detection. Failed or empty chunks are skipped. The WAV chunk file is deleted after
each attempt, even when the request fails. The raw full-recording file is
deleted after WAV conversion, and the full WAV is deleted after final
transcription. On end/restart, the live processor stops and finishes its one
in-flight request before the final transcript request starts.

## Android check

1. Build/run with the existing `.env.json` configuration and internet access.
2. In Practice Setup, enable **Filler-word monitoring**, **Speaking-pace
   monitoring**, and **Live feedback**.
3. Complete Device Check, position the camera, and press **I'm Ready**.
4. After the countdown, say a short sentence containing `kuan`, `ano`, or
   another supported filler. Keep speaking for at least ten seconds so a
   chunk is submitted. A short filler alert should appear after upload and
   transcription latency.
5. Try a sentence without a filler. No filler alert should appear for that
   chunk. Repeat the same sentence in adjacent chunks to check duplicate
   suppression.
6. Speak fewer than 20 words in one chunk for Slow, 20-26 words for Target, or
   27+ words for Fast. Continue for several chunks to see the three-chunk rolling
   average stabilize instead of switching on every unusual chunk.
7. Turn off mobile data during rehearsal, then restore it. The timer and full
   recording should continue while live chunks fail. End the session with
   internet restored and check the final report transcript, WPM, filler counts,
   and any Prepared/Persuasive script comparison.
8. Try Live feedback off: no live filler alerts or live pace should appear,
   while the final report still uses the full recording.

Live Whisper is chunked upload, not continuous streaming. Alert latency is at
least the chunk duration plus network/model time. Overlap increases uploaded
live audio duration by about 7.5% after the first request, but does not increase
the request count. Provider billing and rate-limit behavior must still be
checked against the active Groq plan. Groq's documentation states
that requests under 10 seconds have a 10-second minimum billed duration:
https://console.groq.com/docs/speech-to-text . Test usage against your account
limits. If PCM capture is unsupported by a phone, SpeakSync falls back to its
existing full AAC recording; live alerts may be unavailable on that device.
At 16 kHz mono PCM16, ten minutes of full WAV audio uses about 19.2 MB, within
the service's existing 25 MB free-tier request cap. Longer open-ended sessions
may exceed that cap; the app's existing final transcription error path applies.

Unit/widget tests validate formats, chunk ordering, filler detection, duplicate
suppression, failures, UI gating, and report separation. Native microphone and
network behavior still require a physical Android device check.
