# SpeakSync Data Dictionary

## 1. Overview

SpeakSync uses Hive for local persistence. Hive boxes act as collections, and
their keys act as primary keys. Relationships are stored as string IDs and are
validated by `HiveRepository` because Hive does not enforce foreign keys.

**Legend**

- **PK:** Primary key and Hive record key
- **LR:** Logical reference to another record
- **Required:** Must be provided before saving
- **Optional:** May be null

## 2. Hive Box Inventory

| Box | Model | Key | Status |
|---|---|---|---|
| `users` | `User` | `userId` | Implemented |
| `appPreferences` | `AppPreferences` | `userId` | Implemented |
| `speechProfiles` | `SpeechProfile` | `speechProfileId` | Implemented |
| `rehearsalSessions` | `RehearsalSession` | `sessionId` | Implemented |
| `fillerWordLogs` | `FillerWordLog` | `logId` | Implemented |
| `performanceReports` | `PerformanceReport` | `reportId` | Implemented |
| `applicationMetadata` | Dynamic metadata | Metadata key | Implemented |

The metadata box stores one-time flags for demo-data seeding and legacy-user
migration.

## 3. User

**Box:** `users`  
**Hive type ID:** `0`

| Field | Type | Key/reference | Requirement |
|---|---|---|---|
| `userId` | String | PK | Required |
| `firstName` | String | - | Required |
| `middleName` | String | - | Optional |
| `lastName` | String | - | Required |
| `email` | String | Unique by application rule | Required |
| `schoolName` | String | - | Optional |
| `createdAt` | DateTime | - | Required |

No password field is stored in this model. The previous Hive password field was
removed, and legacy profiles are migrated without it.

## 4. AppPreferences

**Box:** `appPreferences`  
**Hive type ID:** `1`

| Field | Type | Key/reference | Requirement |
|---|---|---|---|
| `userId` | String | PK and LR to `users.userId` | Required |
| `defaultLanguage` | String | - | Required |
| `defaultDuration` | String | - | Required |
| `liveFeedback` | Boolean | - | Required |
| `bodyMonitoring` | Boolean | - | Required |
| `cameraAttentionMonitoring` | Boolean | - | Required |
| `fillerMonitoring` | Boolean | - | Required |
| `paceMonitoring` | Boolean | - | Required |
| `alertFrequency` | String | - | Required |

## 5. SpeechProfile

**Box:** `speechProfiles`  
**Hive type ID:** `2`

| Field | Type | Key/reference | Requirement |
|---|---|---|---|
| `speechProfileId` | String | PK | Required |
| `userId` | String | LR to `users.userId` | Required |
| `speechTitle` | String | - | Required |
| `speechType` | String | - | Required |
| `languageMode` | String | - | Required |
| `targetDurationSeconds` | Integer | - | Required, non-negative |
| `speechContent` | String | - | Optional |
| `createdAt` | DateTime | - | Required |
| `updatedAt` | DateTime | - | Required |

## 6. RehearsalSession

**Box:** `rehearsalSessions`  
**Hive type ID:** `3`

This model stores rehearsal metadata and monitoring choices. Scores and
feedback are stored separately in `PerformanceReport`.

| Field | Type | Key/reference | Requirement |
|---|---|---|---|
| `sessionId` | String | PK | Required |
| `userId` | String | LR to `users.userId` | Required |
| `speechProfileId` | String | LR to `speechProfiles.speechProfileId` | Required |
| `speechTitle` | String | - | Required |
| `speechType` | String | - | Required |
| `languageMode` | String | - | Required |
| `targetDurationSeconds` | Integer | - | Required, non-negative |
| `durationSeconds` | Integer | - | Required, non-negative |
| `sessionDate` | DateTime | - | Required |
| `liveAlertsEnabled` | Boolean | - | Required |
| `bodyLanguageEnabled` | Boolean | - | Required |
| `fillerWordEnabled` | Boolean | - | Required |
| `speakingPaceEnabled` | Boolean | - | Required |
| `cameraAttentionEnabled` | Boolean | - | Required |

## 7. FillerWordLog

**Box:** `fillerWordLogs`  
**Hive type ID:** `4`

| Field | Type | Key/reference | Requirement |
|---|---|---|---|
| `logId` | String | PK | Required |
| `sessionId` | String | LR to `rehearsalSessions.sessionId` | Required |
| `fillerWord` | String | - | Required |
| `occurrenceCount` | Integer | - | Required, non-negative |
| `detectedTimes` | List<Integer> | - | Required, non-negative values |

`occurrenceCount` must equal `detectedTimes.length`. Detection times are
prototype-generated until real speech processing is implemented.

## 8. PerformanceReport

**Box:** `performanceReports`  
**Hive type ID:** `5`

| Field | Type | Key/reference | Requirement |
|---|---|---|---|
| `reportId` | String | PK | Required |
| `sessionId` | String | LR to `rehearsalSessions.sessionId` | Required and unique per session |
| `totalWords` | Integer | - | Required, non-negative |
| `wordsPerMinute` | Double? | - | Actual final-transcript WPM, null when unavailable |
| `paceScore` | Integer? | - | Null in new reports: scoring policy not implemented |
| `fillerScore` | Integer? | - | Null in new reports: scoring policy not implemented |
| `goodPostureSeconds` | Integer? | - | Genuine acceptable-pose time, otherwise null |
| `postureScore` | Integer? | - | Rounded acceptable-time percentage, only with sufficient valid coverage; not a validated educational score |
| `cameraFacingSeconds` | Integer? | - | Genuine head-facing time, otherwise null |
| `cameraScore` | Integer? | - | Rounded estimated head-facing percentage, only with sufficient valid coverage; not eye contact |
| `overallScore` | Integer? | - | Null in new reports: scoring policy not implemented |
| `coachingTips` | List<String> | - | Final measurement-based advice; legacy tips are not trusted by the UI |
| `textTranscript` | String | - | Optional |
| `createdAt` | DateTime | - | Required |
| `fillerCounts` | Map<String, Integer> | - | Required |
| `recommendedPosture` | String | - | Derived posture advice/unavailability on new saves; legacy fixed text is not displayed |
| `isPrototypeData` | Boolean | - | Required |
| `validPostureSeconds` | Integer? | - | Hive field 25: valid Pose coverage; null for legacy records |
| `validFaceAnalysisMilliseconds` | Integer? | - | Hive field 26: valid Face coverage; null for legacy records |
| `cameraFramingMilliseconds` | Map<String, Integer>? | - | Optional Hive field 27: valid milliseconds classified tooClose, proper, tooFar; unavailable intervals excluded |

Existing field indexes 0–26, type ID 5 and script-comparison fields 17–24 are
unchanged. The optional field 27 supplements older records without rewriting
them. Saved monitoring choices remain in `RehearsalSession` and are restored
to the runtime `PracticeSession`; they gate advice and measured-result displays.
See [Phase 4A](phase_4a_measurement_coaching.md) for availability and compatibility.

## 9. Temporary PracticeSettings

**Storage:** In-memory application state

This model remains temporary between Practice Setup and the completed
rehearsal:

| Field | Type |
|---|---|
| `speechTitle` | String |
| `speechType` | String |
| `languageMode` | String |
| `selectedDuration` | String |
| `monitorBodyLanguage` | Boolean |
| `monitorCameraAttention` | Boolean |
| `monitorFillers` | Boolean |
| `monitorPace` | Boolean |
| `enableLiveFeedback` | Boolean |

When a completed report is saved, these choices are mapped into a
`SpeechProfile` and `RehearsalSession`.

## 10. UI Aggregate: PracticeSession

`PracticeSession` remains the non-Hive view model used by the current Home,
Progress, Ranking, Report, and Session Details screens. It is reconstructed by
joining:

```text
RehearsalSession + PerformanceReport -> PracticeSession
```

Filler detail is available separately through `FillerWordLog`. Keeping this
aggregate prevents a destructive rewrite of the existing interface.

## 11. Relationships

```text
User
 |-- one AppPreferences
 |-- many SpeechProfiles
 `-- many RehearsalSessions
          |-- one PerformanceReport
          `-- many FillerWordLogs
```

| Parent | Child | Relationship |
|---|---|---|
| User | AppPreferences | One-to-one |
| User | SpeechProfile | One-to-many |
| User | RehearsalSession | One-to-many |
| SpeechProfile | RehearsalSession | One-to-many |
| RehearsalSession | PerformanceReport | One-to-one |
| RehearsalSession | FillerWordLog | One-to-many |

## 12. Integrity Rules

The repository applies these rules:

1. Record IDs cannot be empty and are used as unique Hive keys.
2. Durations, word counts, and detection times cannot be negative.
3. Scores must remain between 0 and 100.
4. A filler log must reference an existing rehearsal session.
5. A filler log's count must equal the number of detection times.
6. A performance report must reference an existing rehearsal session.
7. A rehearsal session can have no more than one performance report.
8. Duplicate saves of the same completed report are rejected.
9. Deleting a session also deletes its report and filler logs.
10. An unused speech profile is removed after its final session is deleted.
11. Prototype results set `isPrototypeData` to `true`.
12. Plain-text passwords are never written to Hive.
13. Email addresses are normalized and must be unique between users.
14. Preferences and speech profiles must reference an existing user.
15. Rehearsal sessions must reference an existing speech profile owned by the
    same user.

## 13. Demo Data Seeding

The four demonstration sessions are inserted only when the rehearsal and
report boxes are empty. The `applicationMetadata` box stores a versioned flag
after successful seeding so reopening the app does not duplicate them.

Clearing prototype data removes the related sessions, reports, logs, and
unused speech profiles. The metadata flag remains set, so cleared demo data is
not automatically restored on the next launch.
