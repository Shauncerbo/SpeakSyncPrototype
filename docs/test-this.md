# TEST THIS — SpeakSync Teammate Testing Guide

**Goal:** Check whether SpeakSync works on an Android phone. **No coding needed.**

**Tester:** __________________  **Phone / Android version:** __________________  **Date:** __________

## Before you start

- Install the SpeakSync APK given by your teammate.
- Turn **Wi-Fi or mobile data ON**. Allow **camera and microphone** permissions.
- Use a quiet, well-lit place. Keep your **face, shoulders, and upper body** visible.
- You can start around **1.5–2 meters** from the phone, then adjust using the preview. This is only a suggested distance; the app does not measure meters.

**How to mark tests:** Check `[x]` if it works. If it fails, leave it unchecked and write **FAIL + what happened** in the Notes section. Write **N/A** if you could not test it.

## A. Open the app and complete a rehearsal

- [ ] **T01 — Open app:** Launch SpeakSync. **Expected:** No crash or stuck loading screen.
- [ ] **T02 — Dashboard:** Tap **Sign In** and visit **Home**, **Progress**, and **Settings**. **Expected:** All pages open and scroll. *(Sign In is currently a prototype, not a verified login.)*
- [ ] **T03 — Practice setup:** Tap **Start Practice**; enter a title, speech type, language, duration, and monitoring choices. Tap **Continue**. **Expected:** Setup continues to **Device Check**.
- [ ] **T04 — Camera and sound check:** Open **Camera Preview** and look at **Ambient noise**. **Expected:** Camera opens, your upper body is visible, and noise status appears. The rehearsal timer has not started yet.
- [ ] **T05 — Start rehearsal:** Tap **I'm Ready**. **Expected:** Countdown appears, then recording begins. Microphone level reacts when you speak.
- [ ] **T06 — Camera/posture:** Face the phone, turn your head away, change posture, then move too close/far. **Expected:** Visual feedback responds when detection is available; **no pose dots or skeleton lines** appear.
- [ ] **T07 — Live speech feedback:** Turn **Live feedback ON**, speak for 30+ seconds, and say *kuan* or *kanang*. **Expected:** Filler or pace feedback may appear after processing (not instantly); it must not freeze the app.
- [ ] **T08 — Finish and report:** Tap **End Session** and confirm. **Expected:** A report opens with available transcript, WPM, filler results, and coaching feedback. Note any clearly wrong or missing words.
- [ ] **T09 — Save:** Tap **Save to Progress**, then open the session in **Progress → Session history**. Close and reopen the app. **Expected:** Your saved report is still there.

## B. Test all three speech types

**Sample reference script:** “Good morning everyone. Today I will discuss the importance of communication.”

**Say this instead:** “Good morning everyone. Today I will explain communication......”

- [ ] **T10 — Prepared (typed):** Select **Prepared**, type the sample script, rehearse using the changed version, and open the report. **Expected:** **Reference Script Comparison** shows words/phrases that matched or differed.
- [ ] **T11 — Prepared (upload):** Repeat with **TXT**, **DOCX**, and **text-based PDF** files. **Expected:** Each file's text appears, can be edited, and is compared after rehearsal. **Mark separately:** TXT ___ / DOCX ___ / PDF ___.
- [ ] **T12 — Persuasive:** Select **Persuasive**, type or upload a script, rehearse, then save and reopen the report. **Expected:** Script comparison is saved and the speech type is **Persuasive**, not Prepared.
- [ ] **T13 — Impromptu:** Select **Impromptu** and rehearse. **Expected:** No script is required and no script-comparison results appear.

## C. Check speech, results, and settings

- [ ] **T14 — Languages and fillers:** Try speaking English, Filipino, Bisaya, or a natural mix. Say *ano*, *parang*, *kuan*, *kanang*, and *bitaw*. **Expected:** The transcript generally follows what you said; filler results appear when recognized. **Write down missed or invented words.**
- [ ] **T15 — Live feedback OFF:** Turn Live feedback OFF and complete a rehearsal. **Expected:** No live speech alerts; final transcript and final measurements still work.
- [ ] **T16 — Turn monitoring OFF:** Disable a monitor or cover your face briefly. **Expected:** Missing/disabled visual measurements say **Off** or **Unavailable**, not a made-up zero or score.
- [ ] **T17 — Report checks:** Look at WPM, filler counts, visual results, and feedback. **Expected:** Available data is shown clearly. Numerical Pace, Filler, and Overall Scores may be **Not scored/Unavailable**; this is currently expected.

## D. Extra checks (if you have time)

- [ ] **E01 — No internet:** Save a report, then turn internet OFF. **Expected:** Saved history still opens. Starting a new online transcription may be blocked with a clear message.
- [ ] **E02 — Bad document:** Try an empty file or scanned/image-only PDF. **Expected:** Clear error message instead of a crash; scanned PDFs are not supported for text extraction.
- [ ] **E03 — Permissions:** Deny camera or microphone permission, then retry. **Expected:** Understandable message, not a crash. Restore permission afterward.
- [ ] **E04 — Restart:** During a rehearsal, try **Restart** and cancel, then restart again and confirm. **Expected:** Cancel keeps the rehearsal; confirm restarts it.

## Problems / bugs found

| Test ID | What went wrong? | What should have happened? |
|---|---|---|
| | | |
| | | |
| | | |

If possible, attach a screenshot of the error **without private speech, account information, or another person's face**.

## Final result

**Main rehearsal completed (setup → recording → report → save)?** Yes / No

**Tests passed:** ______  **Failed:** ______  **Not tested:** ______

**Biggest problem:** ___________________________________________________

**Other comments:** ___________________________________________________

> **Note:** SpeakSync is a prototype. This checklist checks whether app features work; it does not prove Whisper or filler-detection accuracy. Use only your own speech or consented recordings.
