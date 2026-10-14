# Near-real-time transcript feedback

The rehearsal microphone is captured once. When Live feedback and either
Filler-word or Speaking-pace monitoring are selected,
`RehearsalAudioRecorder` streams mono 16 kHz PCM16 to a temporary raw file and
splits the same samples into non-overlapping 10-second chunks. At the end, it
wraps the full raw recording as WAV. The full recording is sent through the
existing Groq Whisper service for the final transcript, WPM, filler counts,
script comparison, and report. Without live feedback, the existing AAC/M4A
recording path remains in use.

Each completed live chunk is wrapped as a temporary WAV and passed to a second
instance of the existing `GroqTranscriptionService` with the same app API key.
The short live request times out after 8 seconds. Its transcript goes through
`FillerAnalysis`'s existing normalization and lexicon. The first detected filler
produces a short overlay such as `Filler detected: kuan`. The same transcript,
without another Groq request, also goes through the existing `SpeakingPace`
word counter. Recent WPM is recognized words divided by 10/60 minutes.

Live pace ignores empty transcripts and chunks with fewer than four recognized
words. It displays the arithmetic mean of the latest three valid chunk WPM
values (or all available valid chunks until three exist). Below 120 WPM is
Slow, 120 through 160 is Target, and above 160 is Fast. A failed or insufficient
chunk leaves the previous valid indicator unchanged. Partial transcripts,
live pace values, and live filler results are never saved in the report.

The final full-recording request includes a concise multilingual transcription
prompt that provides the spellings of supported Filipino-Bisaya fillers and
asks for audible fillers to be retained. Live chunk requests do not use this
prompt, so their established detection flow is unchanged. The final filler
frequency is still calculated only from the complete final transcript; live
detections are not added to it.

Only one live request runs at a time, with at most one newer chunk buffered.
The newest replaces an older pending chunk if the API falls behind. Chunks do
not overlap, and consecutive identical normalized transcripts do not alert
twice. Failed or empty chunks are skipped. The WAV chunk file is deleted after
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
least the chunk duration plus network/model time. Groq's documentation states
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
