# Phase 4B: Performance scoring proposal

**Status: PROPOSED - NOT APPROVED, NOT IMPLEMENTED.**  
**Revised against the actual 17-page manuscript:** October 17, 2026 (Asia/Manila).  
**Source baseline:** `bc61a08` and the current working source.  
**Manuscript SHA-256:** `FEAA4041946A3C9A98A15F09E9BAE4BF8396DF9381B9479377E3E84B511E23BC`.  
**Decision gate:** Researchers must explicitly approve the complete specification
below, or provide changes, before scoring implementation begins.

Only this proposal is revised in this review. No application, scoring, Hive
adapter, detector, authentication, notification, or test code is changed.

## 1. Actual manuscript reference and alignment status

**Primary reference:** `ACM_Ranain_Cerbo_Sebellino (2).pdf`, the supplied
17-page manuscript. Printed page numbers and PDF page numbers coincide for the
pages cited here. Sections 2.3.2.2-2.3.2.5 and Tables 5-7 are on pages 12-13;
**Table 8, Illustrative Sample Dataset**, and its worked Session 1 are on page 13.
Equation 1 appears on page 11 and its weighting rationale continues on page 12.
The relevant pages were text-extracted and visually checked against the PDF.

The manuscript itself, not the earlier attachment summary, is now the
methodology reference. This corrects the earlier proposal's claim that no
Posture/Camera category bands were supplied.

Also reviewed: the historical `SPEAKSYNC_SYSTEM_AUDIT.md`, Phase 4A report,
Phase 2A/3 notes, and current measurement, storage and analytics source.
Researcher approval and expert validation remain separate.

| Rule or proposal | Actual manuscript reference | Alignment and unresolved decision |
| --- | --- | --- |
| Final WPM and Slow / Target / Fast boundaries | Section 2.3.2.2, Equation 2, Table 5, p. 12 | Documented. The table's middle label is **Target / Effective**, matching current source. No WPM-to-0-100 conversion is defined. Giving the entire target interval 100 is a proposal, not a manuscript rule. |
| Filler frequency and categories | Section 2.3.2.3, Equation 3, Table 6, p. 12 | Documented integer-labelled categories. Continuous decimal intervals and a complete numerical Filler Score function still need approval. |
| Table 8 numerical filler scores | Illustrative dataset and discussion, p. 13 | Session 1 expressly states 8/minute -> 76. Other rows imply 65, 91, 55 and 81 under Equation 1. Prior F1 contradicts all five; see Section 4. |
| Posture denominator | Section 2.3.2.4 and Equation 4, p. 12; Table 7 continuation, p. 13 | **Internal conflict:** prose says percentage of valid posture-analysis time; Equation 4 divides by Total Session Duration, and a Table 7 cell also says percentage of session. Current code uses valid analysis time. Researchers must reconcile these statements. |
| Camera denominator | Section 2.3.2.5 and Equation 5, p. 12 | **Internal conflict:** prose says valid camera-analysis time; Equation 5 divides by Total Session Duration. Current code uses valid analysis time. This cannot be described as an already-unambiguous manuscript formula. |
| Visual percentage categories | Table 7, pp. 12-13 | Excellent 90-100; Good 70-89; Needs Improvement 50-69; Poor below 50 are **already documented for Posture and Camera**. Decimal boundaries need clarification. Specific posture-type labels in its cells exceed current detector capabilities. |
| Overall weights | Equation 1, pp. 11-12 | Preserve exactly: Pace 25%, Filler 30%, Posture 25%, Camera 20%. Researcher-designed and explicitly subject to expert review. |
| Framing | Narrative around Equation 1, pp. 11-12 | Separate positioning feedback, not an additional weighted metric. |
| Overall interpretation | Session 1 narrative, p. 13 | The manuscript calls 82.30 good overall performance. That is an illustrative interpretation, not a complete Overall Score category table. Extending Table 7's visual categories to all Overall Scores needs explicit clarification. |
| Minimum visual evidence, missing/disabled monitors, precision and rankings | No complete numerical policy in Sections 2.3.2.2-2.3.2.5 or Tables 5-8 | These remain implementation/methodology decisions, not documented assessment criteria. |

Table 8's discussion mentions a separate filler-word scoring table, but the
reviewed PDF does not provide a complete 0-100 frequency-to-score table or
formula. Table 6 supplies frequency interpretations, not those numerical scores.
There is also a separate **Table 8 Users** under the data model on page 13.
References to Table 8 in this review mean the **Illustrative Sample Dataset**;
duplicate numbering should be corrected editorially, not confused with scoring.

**No candidate formula, denominator amendment or coverage gate is adopted by
this revision.** The decision table in Section 11 identifies what is documented
and what researchers still need to approve.

## 2. Measurement inputs, decimal boundaries, and validity

Use only the final full-recording Whisper transcript and genuine on-device
visual summaries. Live chunks, notifications, reference-script word counts,
manual counters, demo records and old numeric grades are not scoring inputs.

Let:

- `N` = final recognized word count from the existing tokenizer.
- `D` = actual elapsed rehearsal duration in seconds, excluding readiness/countdown.
- `H` = dictionary filler occurrences in that same normalized final transcript.
- `w = 60 * N / D` = WPM, following Equation 2 (p. 12).
- `f = 60 * H / D` = detected expressions/minute, following Equation 3 (p. 12).
- `T_P, A_P` = genuine valid and acceptable Pose-analysis durations.
- `T_C, F_C` = genuine valid and generally camera-facing Face-analysis durations.

The existing session-duration definition includes silence while the rehearsal
timer runs, not estimated voiced time. No VAD or silence trimming is proposed.
Current rehearsal timing is whole-second based; more precise storage units do
not create additional capture accuracy.

### Continuous decimal interpretation proposed for approval

Classify unrounded values, not the formatted values displayed to students.

| Measurement | Continuous interval | Manuscript category |
| --- | --- | --- |
| WPM | `0 < w < 120` | Slow |
| WPM | `120 <= w <= 160` | Target / Effective |
| WPM | `w > 160` | Fast |
| Fillers/minute | `0 <= f < 2` | Very Low |
| Fillers/minute | `2 <= f < 6` | Low / Acceptable |
| Fillers/minute | `6 <= f < 12` | Elevated |
| Fillers/minute | `f >= 12` | High |

These preserve Table 5 and the existing application's continuous interpretation
of Table 6. Table 6 itself lists integer ranges and does not expressly define
fractions. Thus 1.99 -> Very Low and 5.99 -> Low / Acceptable are proposed
clarifications, not independently validated findings. Rounding first is an
alternative that would change current behavior: 1.5 would become 2.

Table 7 visual categories are defined separately in Section 5; they must not be
silently extended to Pace, Filler or Overall Scores.

### Speech eligibility

Require `D > 0`, a successful nonempty recognized final transcript, positive
recognized word count for pace, and finite nonnegative derived rates.
An empty, missing or punctuation-only transcript makes both speech scores
unavailable; it does not prove zero-WPM performance or perfect filler avoidance.
A valid recognized transcript with no dictionary matches gives a genuine
`H = 0`, not a missing value.

No additional minimum speech duration is chosen here. Short sessions are
sensitive to individual word recognition errors and should be disclosed.
Visual scoring coverage is an unresolved, separate decision in Section 5.

## 3. Pace Score reassessment: candidates, not an approved formula

Section 2.3.2.2 and Table 5 (p. 12) classify WPM but do not prescribe numerical
penalties or require that every target-rate rehearsal receive 100. The following
are new rubric candidates, not formulas established by the cited speaking-rate
literature.

### P1: previous proportional-penalty candidate

For valid finite positive `w`:

```text
                 100 * w / 120       if 0 < w < 120
PaceScore(w) =    100                 if 120 <= w <= 160
                 100 * 160 / w       if w > 160
```

Invalid inputs are unavailable, not fabricated zeros.

### P2: steeper linear fast-speech penalty

```text
                 100 * w / 120               if 0 < w < 120
PaceScore(w) =    100                         if 120 <= w <= 160
                 max(0, 100 * (240-w)/80)     if w > 160
```

The 240-WPM zero anchor is new and requires approval; it is not a new Fast
category boundary. P2 changes fast-speech penalties, not Table 5 classifications.

| Hypothetical WPM | Table 5 category | P1 raw score, approximately | P2 raw score, approximately |
| --- | --- | --- | --- |
| 60 | Slow | 50.0000 | 50.0000 |
| 100 | Slow | 83.3333 | 83.3333 |
| 119.99 | Slow | 99.9917 | 99.9917 |
| 120 | Target / Effective | 100 | 100 |
| 140 | Target / Effective | 100 | 100 |
| 160 | Target / Effective | 100 | 100 |
| 160.01 | Fast | 99.9938 | 99.9875 |
| 180 | Fast | 88.8889 | 75 |
| 240 | Fast | 66.6667 | 0 |
| 320 | Fast | 50 | 0 |

**Educational trade-offs:**

- P1 is continuous and proportionally symmetric: 60 WPM (half the lower
  boundary) and 320 WPM (twice the upper boundary) both score 50.
- A rate immediately outside the target can score almost 100. That is inherent
  in a continuous curve meeting a 100-point plateau, and P2 does not eliminate
  it. A category label such as Slow/Fast is therefore not a grade such as Poor.
- Smooth penalties avoid large grade changes from one recognition error near
  120/160, but almost-perfect numbers may weaken the instructional message that
  the student is outside the target. Preserve the WPM category and Phase 4A advice.
- P1 gives 240 WPM 66.67 and 320 WPM 50; researchers must decide whether these
  penalties are educationally appropriate. They cannot be justified solely by
  Table 5. P2 is more punitive and saturates at zero, but its 240 anchor and
  asymmetry need a defensible rationale and validation.
- **P3: an explicit categorical or teacher-calibrated rubric** could impose
  lower scores immediately outside target, using researcher-approved values.
  Discontinuities magnify ASR noise near boundaries and fixed band scores lose
  within-category variation. Values must be supplied and approved, not invented
  during coding.

No P1/P2/P3 option is selected in this revision. Table 8 supplies Pace Scores
but no raw WPM, word counts or session durations, so it cannot establish which
curve generated those numbers. Future illustrative sessions must include enough
raw inputs to verify the chosen conversion.

## 4. Filler Score conflict and resolution choices

### 4.1 What all five Table 8 rows imply

The following reproduces the printed dataset (p. 13). Filler Score is not a
column in the manuscript, so solve Equation 1 for it:

```text
Implied Filler Score =
  [Overall - 0.25*Pace - 0.25*Posture - 0.20*Camera] / 0.30
```

| Table 8 session | Fillers/min | Pace | Posture | Camera | Printed Overall | Implied Filler Score |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 8 | 90 | 80 | 85 | 82.30 | **76** |
| 2 | 13 | 75 | 70 | 75 | 70.75 | **65** |
| 3 | 1 | 85 | 90 | 90 | 89.05 | **91** |
| 4 | 15 | 60 | 65 | 70 | 61.75 | **55** |
| 5 | 5 | 96 | 86 | 88 | 87.40 | **81** |

For Session 1, the non-filler contribution is
`22.50 + 20.00 + 17.00 = 59.50`, so
`(82.30 - 59.50)/0.30 = 76`, agreeing with the manuscript's explicit worked
example. The other four scores are algebraically implied, not explicitly printed
as a scoring lookup.

This inference treats the printed component scores as the calculation inputs.
If authors used other unrounded inputs, they must supply them; two-decimal
Overall rounding alone cannot explain the discrepancies with F1 below.

### 4.2 Prior F1 and a tempting 3-point substitute do not reproduce the dataset

The previous proposal's F1 candidate is:

```text
F1(f) = max(0, 100 - 5*f)
```

It gives **60, not 76, at eight fillers/minute**. The following recomputes
Overall using F1 while holding the printed Pace/Posture/Camera scores fixed:

| Session | Implied manuscript Filler Score | F1 score | Overall with F1 | Change from printed Overall |
| --- | --- | --- | --- | --- |
| 1 | 76 | 60 | 77.50 | -4.80 |
| 2 | 65 | 35 | 61.75 | -9.00 |
| 3 | 91 | 95 | 90.25 | +1.20 |
| 4 | 55 | 25 | 52.75 | -9.00 |
| 5 | 81 | 75 | 85.60 | -1.80 |

A replacement `max(0,100-3*f)` happens to produce 76 at 8/minute, but gives
Session 2 **61 instead of 65**, Session 3 **97 instead of 91**, and Session 5
**85 instead of 81**. It also matches Session 4's 55. Therefore matching the
single stated eight/minute example does not resolve the complete inconsistency.

The implied anchors ordered by frequency are
`(1,91), (5,81), (8,76), (13,65), (15,55)`.
Their successive slopes differ; no single straight-line penalty reproduces
all five exactly. These are illustrative examples, not empirical calibration data.

### 4.3 Explicit alternatives requiring a researcher decision

| Resolution path | What stays | What must be supplied or revised | Limitation |
| --- | --- | --- | --- |
| **R1: preserve every existing Table 8 value** | All five printed component/Overall values and the implied filler anchors above. | Recover the intended separate numerical scoring table, or approve a complete function that fits every anchor, including fractions, zero frequency, intermediate points and frequencies outside 1-15. Add explicit Filler Score values to the examples for reproducibility. | Five anchors do not identify a unique formula. No arbitrary lookup/interpolation may be implemented as if already documented. |
| **R2: adopt F1 as a NEW numerical rule** | Table 6 frequency categories and the fixed Overall weights. | Approve the 5-point/minute penalty and 20/minute zero anchor. Revise Table 8's five Overall results to the F1 values above if the other components stay fixed; revise the Session 1 paragraph and its worked calculation. | F1 contradicts the current illustrations. It must be described as a methodology revision, not an implementation of an existing formula. |
| **R3: choose another newly defined function** | Documented rate categories and weights. | Approve every parameter and regenerate all illustrative scores/Overall calculations. A 3-point linear penalty still requires changing Sessions 2, 3 and 5. | Matching one or two illustrations is insufficient. Educational justification and expert validation are still needed. |

A piecewise interpolation could fit the R1 anchors, but choosing interpolation,
an additional `f=0` anchor, and the tail beyond 15/minute would itself create a
new rubric. It risks overfitting hypothetical examples. Do not silently infer it.

F1's five-point slope and 20/minute saturation remain **unapproved candidates**.
Other candidates such as `100/(1+f/6)` also do not reproduce Table 8; they would
require the R3 revision process. No resolution path is adopted here. A coherent,
educationally justified full rubric is preferable to accidental curve fitting,
but researchers must decide whether the illustrations or the numerical rule
will be revised.

The recomputed Overall values above are a **partial algebraic audit**, not fully
verified replacement sessions: Table 8 lacks raw WPM and valid visual durations.
If the approved pace or coverage policy changes eligibility or component values,
all components and Overall must be regenerated from explicit hypothetical raw data.

### 4.4 Frequency interpretation and semantic limitations remain separate

Table 6 categories do not themselves define Filler Score points. Retain the
approved frequency interpretation even if the score curve changes. Dictionary
words such as `kasi`, `parang`, `bitaw` and `kuan` can be meaningful; a
dictionary-match score is not proof that every occurrence was a hesitation.
Whisper may omit spoken fillers. Preserve the Phase 4A contextual disclaimer
and actual final transcript counts; do not alter the lexicon to improve grades.

## 5. Visual categories, denominator conflict, and coverage choices

### 5.1 Reconcile the manuscript's two denominator descriptions

Section 2.3.2.4 describes the percentage of **valid posture-analysis time**, but
Equation 4 explicitly divides by **Total Session Duration**. Section 2.3.2.5
likewise describes **valid camera-analysis time**, while Equation 5 also uses
**Total Session Duration**. Table 7's posture wording includes "of session".

Current source and the earlier proposal use:

```text
Observed posture percentage = 100 * A_P / T_P
Observed camera percentage  = 100 * F_C / T_C
```

**Recommendation for review:** retain valid-analysis denominators so missing
landmarks are not silently counted as poor posture or looking away. Researchers
must approve the clarification and amend Equations 4-5 and relevant Table 7
wording to match. This is not already an unambiguous literal match to those equations.

For example, 30 acceptable seconds / 30 valid seconds during a 180-second
rehearsal gives 100% of valid observations but 16.67% of total session time.
These are different quantities. The missing 150 seconds must not automatically
be classified as unacceptable posture. If total-session normalization is truly
intended, an explicit unknown-time policy is needed; do not change software to
one interpretation without resolving the manuscript.

### 5.2 Table 7 categories: documented, with decimal clarification proposed

Table 7 spans pages 12-13 and already supplies these categories for **both
Posture Score and Camera Score**. Apply them only to an eligible, genuine score.

| Table 7 category | Printed integer band | Proposed continuous raw-score interval |
| --- | --- | --- |
| Excellent | 90-100 | `90 <= s <= 100` |
| Good | 70-89 | `70 <= s < 90` |
| Needs Improvement | 50-69 | `50 <= s < 70` |
| Poor | Below 50 | `0 <= s < 50` |

Thus 89.99 is Good, 90.00 Excellent, 69.99 Needs Improvement and 49.99 Poor.
The named categories/cutoffs are documented researcher-designed criteria; the
gap-free decimal convention is a proposed clarification. Invalid, disabled or
insufficient measurements have no category, not Poor.

**Do not equate a percentage band with a particular posture type.** Table 7
associates bands with upright, leaning forward, leaning backward, slouching and
shifting descriptions. Current `PostureAnalyzer` uses shoulder tilt and 2D
torso/alignment geometry to classify acceptable/needs-adjustment/invalid samples;
it does not independently identify or validate those specific posture types.
An 80% acceptable-time result does not prove that a student was leaning forward:
many mixtures of observed states could produce 80%.

The proposal preserves the numeric bands as category labels for the measured
time fraction, while asking researchers to amend or qualify the posture-type
wording in Table 7. Do not display "Leaning Backward" or "Slouched" just because
a percentage falls into a band. Validating a new posture-type classifier would
be a separate task, not a hidden part of scoring.

Camera categories label estimated head-facing time, not actual eye contact,
concentration, confidence or audience engagement. Table 7 does not explicitly
extend these bands to Pace, Filler or Overall Scores. Table 8 calls 82.30 good
overall performance, but supplies no complete general Overall category rubric.

### 5.3 Reassess the existing three-second floor

Current Pose and Face summaries allow a percentage after **3.000 valid seconds**.
That is a software availability floor, not a demonstrated adequate assessment
sample. Three seconds is only 1.67% of a three-minute rehearsal and 1% of a
five-minute rehearsal. A perfect ratio over those samples cannot support a
claim of excellent whole-session performance.

Let `coverage_P = T_P / D` and `coverage_C = T_C / D`, with consistent units
and the same actual rehearsal interval. Each monitor qualifies independently.

The following numbers are **illustrative policy alternatives for approval,
not new active requirements or expert-validated thresholds**:

| Candidate | Scoring eligibility per visual component | Advantages | Trade-offs |
| --- | --- | --- | --- |
| **V0: existing floor only** | `T >= 3 seconds` | Preserves current availability; works in short rehearsals. | Allows a tiny nonrepresentative sample to determine a long-session grade. Coverage disclosure alone does not cure this. |
| **V1: larger absolute minimum** | Example: `T >= 30 seconds` | More observed time; simple to explain and test. | Still only 10% of a five-minute rehearsal; rehearsals shorter than 30 seconds cannot qualify. |
| **V2: relative coverage plus existing floor** | Example: `T >= 3 seconds AND T/D >= 0.50` | Scales with rehearsal length and retains short-session support. | Half the session may still be missing; a very short rehearsal can still have few valid seconds. More low-end-device sessions may be unscored. |
| **V3: hybrid absolute and relative minimum** | Example: `T >= 30 seconds AND T/D >= 0.50` | Guards against both tiny samples and low long-session coverage. A practical candidate for piloting with teachers/devices. | More restrictive; short or heavily occluded rehearsals can be unscored. Near-30-second sessions may fail because initialization/warm-up is excluded. Neither 30 nor 50% is manuscript-approved. |

For a 180-second rehearsal, V0 requires 3 valid seconds, V1 requires 30, and
the example V2/V3 policies require 90. For 300 seconds, V2/V3 require 150.
For a 20-second rehearsal V2 requires 10; V1/V3 cannot qualify. These are not
instructions to change runtime behavior. Researchers should choose parameters
using representative devices, classroom use, teacher assessment and the study's
rehearsal protocol. No coverage option is selected in this revision.

Higher coverage does not guarantee representativeness: failures can be systematic
when students turn or move. Report missing-time context and calibrate detectors;
do not count unknown time as bad or relax detection quality just to pass a gate.

### 5.4 Preserve measurements separately from scoring eligibility

A component can have a genuine observed percentage yet lack enough coverage for
a selected assessment policy. Example: 10/10 valid acceptable seconds in a
180-second session is an observed 100%, but fails the example V2/V3 policies.
Keep that raw measurement and its coverage; the assessment score/category would
be unavailable, not zero and not an Excellent whole-session grade.

Do not erase genuine historical percentages or silently alter Phase 4A's
measurement availability contract. Future versioned metadata/readers must
separate raw visual measurements from assessment eligibility, so Phase 4A
coaching remains measurement-based and appropriately qualified. Changing a
scoring gate must not turn actual data into simulated fallback values.

Use genuine accumulated durations, not notification visibility time. Current
Pose gaps over 700 ms and Face gaps over 1200 ms break continuity; invalid
landmarks and camera interruptions are excluded. Preserve current smoothing and
persistent warning behavior. Geometry thresholds remain provisional: Pose
shoulder tilt <=10 degrees / torso lean <=12 degrees; Face outer yaw/pitch
25/20 degrees with tighter recovery. None is recalibrated by this proposal.

Store the highest genuine duration precision available; do not reconstruct it
from truncated saved whole-second counters. Check clock consistency before
using relative coverage; do not silently clamp inconsistent data or invent
extra duration. Always show valid time and coverage alongside an eligible score.
Camera-framing feedback remains separate and unweighted.

## 6. Overall Score and missing-data policy

### Recommended option O1: complete-case overall scoring

Only when all four components are enabled, valid, and available under the same
approved scoring version and the selected visual-coverage policy:

```text
OverallScore = (PaceScore × 0.25)
             + (FillerScore × 0.30)
             + (PostureScore × 0.25)
             + (CameraScore × 0.20)
```

Use unrounded component scores for this calculation. Weights total 1.00 and are
exactly the supplied researcher-designed weights. No framing, script-comparison,
readiness-noise, live-alert, or participation bonus/deduction is added.

| Condition | Individual score | Overall Score |
| --- | --- | --- |
| All components valid | Compute each formula. Genuine zero values participate normally. | Compute the specified weighted sum. |
| One monitor disabled | That component is null with status Disabled; preserve available others. | Null: complete assessment unavailable. |
| Transcript missing/failed/empty or duration nonpositive | Pace and fillers null with an explicit reason. | Null. |
| Valid final transcript, no filler matches | Genuine frequency zero, not missing. Use the approved score mapping: F1 would give 100; R1 still needs an explicit zero-frequency definition. | Available only if that mapping is approved and all other components qualify. |
| Pose/Face missing, failed, or below its minimum | Affected visual score null with an explicit reason; keep other valid scores. | Null. |
| Some missing frames but sufficient coverage under the selected policy | Compute the approved visual fraction; disclose valid time and coverage. A raw observed percentage alone does not establish scoring eligibility. | Available if all four otherwise qualify. |
| Live Feedback OFF, final monitoring ON | Compute from final measurements normally. Live chunks/alerts are irrelevant. | Available if complete. |
| Legacy/demo/unapproved-version record | Do not interpret old numbers as approved scores. | Null in current genuine-score analytics. |
| Android Face/Pose unsupported or unavailable on another platform | Affected score unavailable, not zero. | Null. Do not penalize lack of supported hardware. |

Do not silently substitute zero, a population average, 82%, previous-session
scores, reference-script counts, or simulated measurements.

**Alternative O2: renormalized partial scoring - NOT recommended under the
supplied formula.** Dividing by the available weights changes their effective
contributions and makes incomplete sessions incomparable with complete ones.
It requires an explicitly revised methodology and a separately labelled partial
index; it must not be displayed or ranked as the defined Overall Score.

### Precision and presentation recommendation

1. Classify raw WPM/filler rates, then calculate raw scores, then the raw
   weighted sum. Do not round inputs or individual components first.
2. Persist unrounded results with scoring-version provenance. For published
   scores, display one decimal using nonnegative round-half-up:
   `display(s) = floor(10 × s + 0.5) / 10`.
3. Existing integer Hive score fields can remain rounded compatibility mirrors:
   `integerMirror(s) = floor(s + 0.5)`. Do not use those mirrors for the new
   weighted calculation or averages.
4. Normally show WPM/frequency to two decimals. If a rounded measurement would
   imply another category, also show its raw boundary relation (for example,
   “below 120 WPM; Slow”). Never reclassify from formatted text.
5. Under P1/P2, a displayed Pace Score of 100.0 can result from rounding a score
   slightly below 100 outside target. Always retain the raw WPM category.

## 7. Score-to-category mapping after manuscript review

| Metric | Category source and proposed interpretation |
| --- | --- |
| Pace | Table 5 categories from raw WPM. No numerical score-to-grade bands are supplied. Under P1/P2, raw 100 corresponds to Target / Effective; a rounded 100.0 can occur just outside target, so keep the WPM label. |
| Filler frequency | Table 6 categories from raw expressions/minute, independent of the unresolved score curve. |
| Filler Score if, and only if, F1 is chosen | Very Low maps to `90 < s <= 100`; Low / Acceptable to `70 < s <= 90`; Elevated to `40 < s <= 70`; High to `0 <= s <= 40`. These ranges are consequences of F1, **not** a printed numerical scoring table, and do not reproduce Table 8. They cannot be carried over automatically to R1/R3. |
| Posture | Table 7: Excellent `[90,100]`, Good `[70,90)`, Needs Improvement `[50,70)`, Poor `[0,50)`, using an eligible genuine time-fraction score. Not a diagnosis of specific posture type. |
| Camera | The same Table 7 numeric bands, for eligible estimated head-facing time only. No eye-contact or engagement claim. |
| Overall | Preserve the weighted numeric result. A complete set of Overall categories is unresolved: Table 8's one "good" interpretation does not specify all boundaries. Explicitly approve and document any extension of Table 7 to Overall. |

Classify raw visual percentages before formatting. For example, 89.99 remains
Good even if displayed as approximately 90.0; show the boundary relation or extra
precision when rounding would imply a different category. Missing or
coverage-ineligible measurements must not receive any Table 7 grade.

Visual category colors may be aligned with Table 7 only in an approved future
implementation. The existing dormant 70/80 overall ring color cutoffs are not
a Table 7 mapping (Excellent starts at 90). Keep overall presentation neutral
unless a complete overall interpretation policy is expressly approved.

## 8. Worked-example alignment and candidate-only demonstrations

### 8.1 Actual manuscript examples

All five Table 8 sessions were checked in Section 4. They imply Filler Scores
76, 65, 91, 55 and 81. Preserving their printed Overall values requires a
complete rubric that reproduces those scores; adopting F1 changes the printed
Overall results to 77.50, 61.75, 90.25, 52.75 and 85.60 respectively, with the
other printed scores held fixed.

Table 8 supplies neither raw WPM nor valid Pose/Face durations, so its Pace
scores and visual coverage eligibility cannot be independently reproduced.
No observed student data or new complete formula can be inferred from those
illustrations alone.

### 8.2 Earlier proposal examples A-D: NOT Table 8 or approved student results

These retained hypothetical raw inputs demonstrate **P1 + F1 + valid-time
denominators under V0** only. Their arithmetic is valid for those assumptions,
but the assumptions remain unapproved and differ from the manuscript's examples.

| Example | Duration; words; filler matches | Acceptable/valid Pose seconds | Facing/valid Face seconds |
| --- | --- | --- | --- |
| A | 120 s; 280 words; 4 matches | 90/100 | 70/80 |
| B | 120 s; 360 words; 18 matches | 36/60 | 48/60 |
| C | 180 s; 450 words; 36 matches | 0/90 | 60/60 |
| D | 120 s; 120 words; 2 matches | 30/30 | Unavailable |

| Example | WPM; Table 5 label | Fillers/min; Table 6 label | P1 | F1 | Pose % | Face % | Candidate Overall under V0 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A | 140; Target / Effective | 2; Low / Acceptable | 100 | 90 | 90 | 87.5 | 92.0 |
| B | 180; Fast | 9; Elevated | 88.888888... | 55 | 60 | 80 | 69.7 (raw 69.722222...) |
| C | 150; Target / Effective | 12; High | 100 | 40 | **0 measured** | 100 | 57.0 |
| D | 60; Slow | 1; Very Low | 50 | 95 | 100 | **null unavailable** | **null unavailable** |

These rows are new hypothetical demonstrations, not replacements for the five
manuscript sessions. No values are inserted into source, demo data or Hive.

For A, `w=280/2=140`, `f=4/2=2`, and
`Overall=25+27+22.5+17.5=92`.
For B, `P1=16000/180=88.888888...`, `F1=100-5*9=55`, and
`Overall=22.222222...+16.5+15+16=69.722222...`.

Their visual categories under Table 7, **when eligible**, would be:

| Example | Pose category | Face category | Coverage-policy consequence |
| --- | --- | --- | --- |
| A | Excellent | Good | Pose coverage 83.33%, Face 66.67%; eligible under the example V0-V3 gates. |
| B | Needs Improvement | Good | Both have 50% coverage; eligible under the example V0-V3 gates. |
| C | Poor, a genuinely measured zero | Excellent only if eligible | Pose coverage 50%, Face 33.33%. V0/V1 permit the candidate Overall 57.0; V2/V3 make Camera Score and Overall unavailable. Do not keep 57.0 if a stricter gate is selected. |
| D | Excellent only if eligible | No category | Pose coverage 25% fails V2/V3; Face is unavailable under every option. Overall is unavailable in all cases. |

For C, zero contributes zero at its fixed 25% weight if eligible; it is not
missing. For D under V0, known contributions total 66. Displaying 66 treats
missing Camera as zero; renormalizing to `66/0.8=82.5` changes the weights.
Neither is the defined Overall Score.

If Equation 4/5 total-session denominators were selected instead, even the A-D
visual percentages would change. If another pace/filler curve or coverage
gate is approved, these demonstrations must also be regenerated. They are not
evidence validating any candidate.

## 9. Differences from current source and implementation implications

| Current source evidence | Current behavior | Change needed only after approval |
| --- | --- | --- |
| `lib/services/speaking_pace.dart`: `SpeakingPace.fromTranscript`, `classification` | Genuine WPM and Target / Effective wording already match Table 5; no numerical conversion. | Add only an approved P1/P2/P3 mapping, preserving categories. |
| `lib/services/filler_analysis.dart`: `FillerAnalysis.fromTranscript`, `perMinute`, `classification` | Genuine dictionary matches; continuous decimal bands already exist; no score conversion. | Approve the decimal convention and conversion; keep lexical/context limitations explicit. |
| `lib/services/posture_analysis.dart`: `PostureSummary.acceptablePercentage` | Genuine valid-time fraction, minimum 3 s. Matches the section's prose, not Equation 4's literal total-session denominator. No Table 7 category mapping or validated specific-posture classifier. | Resolve denominator wording, add approved eligibility/categories, and do not infer posture types from percentages. |
| `lib/services/face_attention.dart`: `FaceAttentionSummary.percentage` | Genuine valid-time head-facing ratio, minimum 3 s. Matches section prose, not Equation 5's literal total-session denominator. | Resolve denominator, adopt approved coverage and Table 7 decimal categories; retain head-orientation limitations and warning behavior. |
| `lib/screens/practice_flow.dart`: rehearsal report construction | Rounds visual percentages into nullable integer fields; good/facing times are truncated to seconds. | Calculate proposed raw scores before truncation; retain raw evidence for reproducibility. No live chunks enter final scoring. |
| `lib/models/performance_report.dart`: fields 4/5/7/9/10 | Existing score fields are `int?`; fields 25/26/27 provide visual provenance/framing. | Preserve all existing types/indexes; add compatible raw-score/version metadata if approved. |
| `lib/storage/hive_repository.dart`: `_recordsFromPracticeSession`, `_validateReport` | New pace/filler/overall values are forced null; writes of non-null unvalidated scores are rejected. | Replace the blanket prohibition with versioned, measurement-backed validation, not unconditional acceptance of any number. |
| `lib/models/practice_session.dart`: `validatedOverallScore` | Always null; genuine visual percentages have separate availability gates. | Add approved-version eligibility; never enable scores merely because a stored legacy numeric field is non-null. |
| `lib/services/measurement_coaching.dart` | Phase 4A recommendations use actual measurements and monitoring flags, not overall-score thresholds. | Preserve this behavior. A low overall score must not automatically trigger a filler recommendation. |
| `lib/state/app_state.dart`: `averageScore` | Filters the unavailable overall getter; averages rounded integers when any qualify. | Average eligible unrounded versioned results, not old numeric fields or nulls treated as zero. |
| `lib/screens/home_screen.dart`, `lib/widgets/common_widgets.dart`: session tiles | Some text is explicitly hardcoded “Not scored”. | Wire valid new results; retaining only the existing getter is insufficient. |
| `lib/screens/progress_screens.dart`: ranking and `_ImprovementCard` | Rankings filter unavailable overall scores; a dormant negative-difference message assumes fillers caused a decline. | Use comparable approved results for ranking, and Phase 4A measurements for recommendations rather than guessing a cause. |
| `lib/widgets/common_widgets.dart`: `_ProgressChartPainter` | Dormant score chart clamps values below 40 to 40. | Display genuine full 0-100 results without raising low scores to 40. This becomes necessary when scores are enabled. |
| `lib/widgets/common_widgets.dart`: `ScoreRing` | Dormant overall color changes at 70/80. Table 7 visual bands instead start Excellent at 90 and do not explicitly define all Overall categories. | Do not reuse 80 as Excellent or silently apply visual bands to Overall. Use neutral overall colors until a complete overall policy is approved. |
| `SPEAKSYNC_SYSTEM_AUDIT.md` | Original prototype-score findings are historical; later supplements describe removals and real measurements. | Do not restore the old fixed/deduction formulas described in that historical audit. |

### Proposed persistence/provenance contract for approval

Keep `PerformanceReport` type ID **5** and field indexes **0-27** untouched.
Do not change existing `int?` score fields to doubles in place. Preserve box
names, relationships, monitoring flags and old records.

Recommend one **optional appended field 28**, provisionally named
`scoringMetadata`, containing primitive/nested-map values supported by the
existing storage approach. This is a schema **proposal**, not an adapter change.
Its exact typed representation must be tested during the approved implementation.
The PDF's Table 10 (p. 14) describes double-valued score fields, while actual
Hive fields 4/5/7/9/10 are `int?`. That documentation difference does not
justify changing their serialized types in place; reconcile the manuscript
with the approved compatible representation.

The metadata should contain:

- An allowlisted scoring version, proposed `phase4b.v1`, assigned only to newly
  computed records after approval. Version identifies the formula constants,
  decimal categories (including Table 7), weights, rounding, denominator choice
  and the approved minimum-coverage policy and parameters.
- The frozen final word count, detected dictionary counts, effective rehearsal
  duration and derived WPM/frequency used in the calculation. Preserve tokenizer/
  lexicon version information so a future matcher change cannot silently regrade it.
- Genuine precise acceptable/valid Pose and facing/valid Face durations, and
  the relevant detector-threshold configuration/version, not invented time from scores.
- Per-component raw scores and explicit availability reasons such as Available,
  Disabled, Missing transcript, Invalid duration, Analysis failed, or Insufficient
  visual data. Missing component raw scores are null.
- Separate raw observed visual percentages/coverage from assessment eligibility.
  If a stricter score gate fails, preserve actual measurements for Phase 4A
  without assigning an assessment category or fabricating a zero. New readers
  must preserve that distinction instead of treating a missing grade as no data.
- The raw overall value, or null with a complete-assessment-unavailable reason.
  Existing created-at/session fields continue to identify the report.

Existing integer score fields remain rounded mirrors of approved raw scores.
New validation must verify formula outputs, source prerequisites, monitoring
flags, time consistency, bounds, nullability, and overall completeness. It must
reject inconsistent mirrors/metadata rather than silently trusting them.
`isPrototypeData` alone cannot establish or deny scoring provenance: current
genuine sessions also use that prototype flag.

**Legacy policy:** a record without recognized scoring metadata remains unscored
for overall/pace/filler analytics. Continue showing genuine historical raw
measurements and coverage-backed visual percentages. Do not backfill a version
onto old numbers or automatically rewrite/recompute historical scores. A future
explicit rescoring/export feature would need separate authorization and provenance.

Older readers may ignore an optional added field, but old APKs can discard it
if they rewrite a record. Pre-nullable adapters retain their known inability
to read newly saved null scores. Downgrade compatibility must be tested and
documented; never resolve incompatibility by resetting or deleting Hive data.

## 10. Reports, coaching, progress, and ranking policy

- **Reports and saved details:** show raw measurements, categories, individual
  scores, eligible Table 7 visual categories, valid time/coverage, and complete
  Overall Score or its unavailable
  reason. Label these “researcher-designed provisional scores” until validated.
  Display disabled and unavailable differently from measured zero.
- **Coaching:** keep Phase 4A measurement-based recommendations. Do not infer
  factual correctness, script quality, confidence, or engagement from a score.
  Script comparison remains separate and unchanged. Preserve observed-data coaching
  when a stronger grading-coverage gate fails, with an explicit limited-coverage
  qualification; do not claim it establishes excellent whole-session performance.
- **History:** retain every existing rehearsal. Older records remain selectable
  with measurements and advice; they are not assigned artificial grades.
- **Averages:** arithmetic mean of available unrounded Overall Scores within a
  comparable scoring cohort. Show the eligible-session count, not an average
  that silently includes unscored sessions as zeros. Empty cohort is unavailable.
- **Trends:** use eligible results on a genuine 0-100 axis in chronological order.
  Indicate unscored gaps; do not bridge a missing session as measured improvement.
  Do not mix different scoring versions without an explicit comparison policy.
- **Improvement:** compare the two latest eligible results in the same cohort,
  noting if unscored sessions were skipped. The difference is not proof that any
  one component caused the change; coaching must inspect the actual components.
- **Rankings:** within the current user's rehearsal history, not a new global
  student leaderboard. Recommended cohorts require the same scoring version,
  speech type, language mode and complete four-component eligibility. Show
  duration/coverage context; different durations are not assumed equivalent for
  research comparisons. Cross-type/language/version comparison needs approval.
- **Ties:** recommend ordering by the published one-decimal Overall Score and
  giving equal displayed scores equal competition ranks (1, 2, 2, 4). Date/time
  descending and session ID can order tied rows without implying a better grade.
  Keep raw values for formula reproduction and cohort averages, not tiny hidden
  differences as a tie-breaker. This ranking policy also requires approval.
- **Notifications and privacy:** preserve silent persistent in-camera visual
  warnings, temporary filler alerts, pace freshness behavior, operational
  notifications, on-device frame processing and existing audio/transcription
  handling. Warning counts/durations are not extra scoring penalties.

## 11. Concise approval-decision table

All decisions remain pending; no implementation is authorized by this revision.

| Decision | Already documented in the PDF | Approval/clarification needed |
| --- | --- | --- |
| **D1. Filler conflict** | Table 8 explicitly has 8/min -> 76 and implies five anchors. | Choose **R1** (keep all examples and provide/approve a complete compatible rubric), **R2** (approve F1 and revise all affected examples), or **R3** (another complete rule and revised examples). No silent choice. |
| **D2. Pace conversion** | Table 5 WPM categories, not point penalties. | Choose P1, P2 (including the new 240 zero anchor), or a complete P3 rubric after reviewing near-boundary and very-fast-speech trade-offs. |
| **D3. Decimal frequency boundaries** | Tables 5-6 show integer-labelled bands. | Confirm raw-value, gap-free intervals; do not round before classification unless explicitly chosen. |
| **D4. Visual denominators** | Prose says valid analysis; Equations 4-5 say total session duration. | Resolve the conflict. Recommendation: valid-only ratios, with equations and Table 7 wording amended to agree. |
| **D5. Visual category labels** | Table 7 already supplies Excellent/Good/Needs Improvement/Poor. | Confirm continuous 90/70/50 boundaries and qualify/remove unsupported posture-type inferences. Categories require scoring eligibility. |
| **D6. Coverage requirement** | No numerical minimum assessment-coverage policy. | Select V0/V1/V2/V3 or justified parameters after testing. Existing 3 s is not established sufficient evidence for a long rehearsal. |
| **D7. Overall weights/policy** | Exact 25/30/25/20 weights; framing unweighted. | Preserve weights; approve complete-case Overall. A required monitor OFF, missing or insufficient makes Overall unavailable, never zero or renormalized. |
| **D8. Overall categories** | Table 8 calls 82.30 good, but no complete Overall table. | Keep numeric-only or explicitly define/document complete Overall bands. Do not assume Table 7 automatically applies. |
| **D9. Precision and storage** | Manuscript examples use decimals; current Hive score fields are nullable integers. | Approve raw precision, rounded mirrors, versioned optional metadata and separate measurement-versus-scoring eligibility without altering existing IDs/indexes. |
| **D10. History and comparisons** | No complete legacy/ranking/cohort rules in these sections. | Approve legacy exclusion/no automatic rewrite, comparable-cohort analytics, coverage disclosure and the proposed tie policy. |
| **D11. Manuscript examples** | Five illustrative, not empirical, sessions. | Add the full score mapping and sufficient raw inputs; regenerate every affected calculation after decisions, not just the eight/minute example. |
| **D12. Validation and release** | Manuscript explicitly says researcher-designed criteria require expert review/calibration. | Obtain public-speaking teacher/expert review, real-device coverage tests and review of dictionary/ASR limitations. Researcher approval alone is not expert validation. |

The denominator conflict, missing numerical filler rubric, posture-type wording,
decimal conventions and minimum evidence must be resolved explicitly in the
methodology, not hidden inside implementation. Reviewers may approve some items
and request changes to others, but the complete scoring specification must be
settled before implementation starts.

## 12. Verification plan after approval - not executed in this review

Implementation must add tests for all formulas, exact and adjacent decimal
boundaries (including Table 7 at 49.99/50, 69.99/70, 89.99/90), finite/invalid
inputs, missing/disabled/failed data, genuine zero, and unchanged final-vs-live
independence. Test exact duration/coverage boundaries for the policy actually
approved, including short/long rehearsals and raw-measurement versus grade
eligibility. Do not assume the existing 2.999/3.000-second boundary alone is
sufficient assessment coverage. Include precision and strict fixed-weight
Overall calculations. Include the hypothetical examples as
clearly labelled fixtures, not as app demo/student data.

Integration tests must cover new-report save/reopen equivalence, legacy numeric
and nullable wire formats, optional metadata absence, unknown versions, rejected
inconsistent metadata, no automatic historical rewrite, disabled monitoring,
averages, full-range charts, comparable ranking/ties and Phase 4A coaching.
Existing Face/Pose/framing, Whisper, script comparison, notification and
responsive-layout regressions must remain passing.

Only after approved implementation: run formatting, `flutter analyze`, the full
Flutter suite, and a fresh Android debug build; report actual observed results,
exact changed files, migration/downgrade limitations and phone-validation needs.

**This review's verification:** the actual 17-page PDF was reviewed, relevant
pages 12-13 visually checked, all five Table 8 implied Filler Scores and
candidate recalculations checked, and the hypothetical arithmetic verified.
No scoring implementation or manuscript edit was produced. Flutter tests, analysis and APK build were **not
rerun** for this documentation-only review. Prior Phase 4A results are historical,
not new Phase 4B verification results.

**STOP HERE. Await explicit researcher approval before implementation.**
