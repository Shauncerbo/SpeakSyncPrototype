# SpeakSync Data Dictionary

## 1. Document Overview

This document defines the proposed local NoSQL database structure for the
SpeakSync mobile application. SpeakSync uses Hive boxes instead of relational
database tables. Keys stored in related objects provide logical relationships;
Hive does not enforce foreign-key constraints.

**Legend**

- **PK** — Primary key used as the Hive record key.
- **LR** — Logical reference to a key in another box.
- **Required** — A value must be supplied before the record is saved.
- **Optional** — The value may be null or omitted.
- **Derived** — Calculated from other stored records and does not need to be
  saved.

## 2. Hive Box Inventory

| Box name | Proposed model | Hive key | Purpose | Status |
|---|---|---|---|---|
| `users` | `UserModel` | `userId` | Stores the local student profile | Partially implemented |
| `sessions` | `PracticeSession` | `sessionId` | Stores completed rehearsal reports | Model implemented; Hive adapter pending |
| `preferences` | `AppPreferences` | `userId` | Stores each student's application defaults | Model implemented; Hive adapter pending |
| `goals` | `PracticeGoal` | `goalId` | Stores weekly or personal rehearsal goals | Proposed |
| `rehearsal_events` | `RehearsalEvent` | `eventId` | Stores timestamped rehearsal alerts | Proposed |

`PracticeSettings` is currently temporary setup state. It does not require a
separate box unless unfinished rehearsal setup must be restored after the app
is closed.

## 3. Users Box

**Box:** `users`  
**Hive key:** `userId`  
**Purpose:** Stores the profile of a Senior High School student using SpeakSync.

| Field | Data type | Key/Reference | Requirement | Example | Description |
|---|---|---|---|---|---|
| `userId` | String | PK | Required | `user-001` | Unique identifier of the student |
| `firstName` | String | — | Required | `Maria` | Student's given name |
| `middleName` | String | — | Optional | `Santos` | Student's middle name |
| `lastName` | String | — | Required | `Cruz` | Student's family name |
| `email` | String | Unique | Required | `maria@school.edu.ph` | Student's sign-in or contact email |
| `schoolName` | String | — | Optional | `Sample National High School` | Name of the student's school |
| `createdAt` | DateTime | — | Required | `2026-07-11T09:30:00` | Date and time the profile was created |

**Security note:** A plain-text `password` field currently exists in
`User`. It should not be included in the final stored data design. Passwords
should be handled by a proper authentication service, not stored directly in a
Hive box.

## 4. Sessions Box

**Box:** `sessions`  
**Hive key:** `sessionId`  
**Purpose:** Stores the results and feedback produced by each completed
rehearsal.

| Field | Data type | Key/Reference | Requirement | Example | Description |
|---|---|---|---|---|---|
| `sessionId` | String | PK | Required | `session-001` | Unique rehearsal identifier; corresponds to the current model's `id` |
| `userId` | String | LR → `users.userId` | Required | `user-001` | Student who owns the rehearsal |
| `title` | String | — | Required | `Climate Change Speech` | Student's speech title |
| `speechType` | String | — | Required | `Persuasive` | Prepared, impromptu, informative, or persuasive speech |
| `languageMode` | String | — | Required | `English–Filipino` | Language configuration used during rehearsal |
| `dateTime` | DateTime | — | Required | `2026-06-18T14:20:00` | Date and time the rehearsal occurred |
| `duration` | Duration | — | Required | `00:06:20` | Total rehearsal duration |
| `overallScore` | Integer | — | Required | `82` | Combined performance score from 0 to 100 |
| `paceScore` | Integer | — | Required | `84` | Speaking-pace score from 0 to 100 |
| `fillerScore` | Integer | — | Required | `78` | Filler-word control score from 0 to 100 |
| `postureScore` | Integer | — | Required | `86` | Posture score from 0 to 100 |
| `attentionScore` | Integer | — | Required | `80` | Camera-facing attention score from 0 to 100 |
| `fillerCounts` | Map<String, Integer> | — | Required | `{"Kuan": 3, "Ano": 1}` | Count of each detected localized filler word |
| `coachingTips` | List<String> | — | Required | `["Use a quiet pause."]` | Post-session coaching recommendations |
| `textTranscript` | String | — | Optional | `Good morning everyone...` | Complete rehearsal transcript |
| `transcriptLines` | List<String> | — | Optional | `["Good morning..."]` | Transcript separated into lines or segments |
| `recommendedPosture` | String | — | Required | `Keep your shoulders relaxed.` | Suggested posture improvement |
| `isPrototypeData` | Boolean | — | Required | `true` | Identifies simulated prototype reports |
| `videoPath` | String | — | Optional | `/sessions/session-001.mp4` | Proposed local path to the recorded video; the video itself is not stored in Hive |

The current model includes `gestureCounts`, but the repeated-gesture feature was
removed from the interface. The field may be removed before finalizing the Hive
adapter if the feature is no longer part of the approved scope.

## 5. Preferences Box

**Box:** `preferences`  
**Hive key:** `userId`  
**Purpose:** Stores persistent application and rehearsal defaults for one
student.

| Field | Data type | Key/Reference | Requirement | Example | Description |
|---|---|---|---|---|---|
| `userId` | String | PK and LR → `users.userId` | Required | `user-001` | Owner of the preference record |
| `defaultLanguage` | String | — | Required | `Mixed Language` | Default rehearsal language mode |
| `defaultDuration` | String | — | Required | `3 minutes` | Default target rehearsal duration |
| `liveFeedback` | Boolean | — | Required | `true` | Enables subtle real-time feedback alerts |
| `vibrationFeedback` | Boolean | — | Required | `false` | Enables vibration feedback when supported |
| `bodyMonitoring` | Boolean | — | Required | `true` | Enables posture monitoring by default |
| `cameraAttentionMonitoring` | Boolean | — | Required | `true` | Proposed default for camera-facing attention monitoring |
| `fillerMonitoring` | Boolean | — | Required | `true` | Enables localized filler-word monitoring by default |
| `paceMonitoring` | Boolean | — | Required | `true` | Proposed default for speaking-pace monitoring |
| `alertFrequency` | String | — | Required | `Balanced` | Preferred frequency of real-time coaching reminders |

## 6. Temporary Practice Settings

**Storage:** In-memory application state  
**Purpose:** Holds the student's choices between Practice Setup and the active
rehearsal. This is not a permanent Hive box in the current design.

| Field | Data type | Requirement | Example | Description |
|---|---|---|---|---|
| `speechTitle` | String | Required | `Environmental Awareness` | Title entered for the upcoming rehearsal |
| `speechType` | String | Required | `Prepared` | Selected speech category |
| `languageMode` | String | Required | `Mixed Language` | Selected rehearsal language |
| `selectedDuration` | String | Required | `3 minutes` | Selected target duration |
| `monitorBodyLanguage` | Boolean | Required | `true` | Enables posture monitoring |
| `monitorCameraAttention` | Boolean | Required | `true` | Enables camera-facing attention monitoring |
| `monitorFillers` | Boolean | Required | `true` | Enables filler-word monitoring |
| `monitorPace` | Boolean | Required | `true` | Enables speaking-pace monitoring |
| `enableLiveFeedback` | Boolean | Required | `true` | Enables overlay alerts during rehearsal |

## 7. Goals Box

**Box:** `goals`  
**Hive key:** `goalId`  
**Purpose:** Stores weekly or personal rehearsal targets shown on the Home
screen.

| Field | Data type | Key/Reference | Requirement | Example | Description |
|---|---|---|---|---|---|
| `goalId` | String | PK | Required | `goal-001` | Unique goal identifier |
| `userId` | String | LR → `users.userId` | Required | `user-001` | Student who owns the goal |
| `goalType` | String | — | Required | `weeklySessions` | Category of goal being measured |
| `targetValue` | Integer | — | Required | `3` | Number or score the student wants to reach |
| `startDate` | DateTime | — | Required | `2026-07-06` | Beginning of the goal period |
| `endDate` | DateTime | — | Required | `2026-07-12` | End of the goal period |
| `isActive` | Boolean | — | Required | `true` | Indicates whether the goal is currently active |
| `completedValue` | Integer | — | Derived | `2` | Progress calculated from matching saved sessions |

## 8. Rehearsal Events Box

**Box:** `rehearsal_events`  
**Hive key:** `eventId`  
**Purpose:** Stores a timeline of alerts produced during a rehearsal for later
review.

| Field | Data type | Key/Reference | Requirement | Example | Description |
|---|---|---|---|---|---|
| `eventId` | String | PK | Required | `event-001` | Unique alert-event identifier |
| `sessionId` | String | LR → `sessions.sessionId` | Required | `session-001` | Rehearsal associated with the event |
| `eventType` | String | — | Required | `fillerWord` | `fillerWord`, `pace`, `posture`, or `attention` |
| `message` | String | — | Required | `Filler word detected` | Alert shown to the student |
| `timestampSeconds` | Integer | — | Required | `18` | Seconds elapsed when the alert occurred |
| `severity` | String | — | Required | `warning` | Visual priority of the event |
| `detectedValue` | String | — | Optional | `Kuan` | Word, pace state, or other value linked to the event |

## 9. Logical Relationships

```text
USERS
  │
  ├── 1 : many ── SESSIONS
  │                   │
  │                   └── 1 : many ── REHEARSAL_EVENTS
  │
  ├── 1 : 1 ───── PREFERENCES
  │
  └── 1 : many ── GOALS
```

| Parent | Child | Relationship | Logical reference |
|---|---|---|---|
| User | Session | One-to-many | `sessions.userId` → `users.userId` |
| User | Preferences | One-to-one | Preferences box key → `users.userId` |
| User | Goal | One-to-many | `goals.userId` → `users.userId` |
| Session | Rehearsal Event | One-to-many | `rehearsal_events.sessionId` → `sessions.sessionId` |

## 10. Validation and Storage Rules

1. Every Hive `typeId` must be unique across the application.
2. Existing `HiveField` numbers must never be changed or reused after data has
   been released.
3. Email addresses should be normalized and validated before saving.
4. Scores must remain within the range 0–100.
5. Rehearsal duration and event timestamps cannot be negative.
6. Plain-text passwords must not be stored in Hive.
7. Audio and video files should be saved in application file storage; Hive
   should contain only their local paths and metadata.
8. Deleting a user should also remove their preferences, goals, sessions, and
   related rehearsal events through application code.
9. Prototype-generated reports must set `isPrototypeData` to `true`.
