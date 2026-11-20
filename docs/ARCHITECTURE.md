# ARCHITECTURE.md — Implementation Blueprint

**Physical test baseline:** Apple Watch SE (2nd generation, 2022) with S8 SiP; test on-device Core Motion and HealthKit workout behavior, real sampling rate, rest haptics, and battery. No dependency on ECG, temperature sensor, newer Watch gestures, or Apple Intelligence.

## Reference architecture
```text
Watch SwiftUI
    | WorkoutCoordinator (state machine + explicit user actions)
    +-- HKWorkoutSession / HKLiveWorkoutBuilder (authorized session, optional HR)
    +-- MotionSource (CMMotionManager -> timestamped IMU samples)
    +-- MotionPipeline (resample / filter / window / quality checks)
    +-- ActivityGate -> ExerciseClassifier -> RepCounter -> SetDetector
    +-- WatchLocalStore (event journal + retry queue)
    +-- RestScheduler (haptic + optional local notification)
    +-- SyncAdapter (WatchConnectivity, async queued transfers)
                               |
                               v
                       iPhone SyncAdapter
                               |
                     Persistence + Reconciler
                               |
             SwiftUI Planner / History / Charts / Editor
                               |
                RuleBasedRecommendationEngine

Python offline experiment -> preprocessing manifest -> classifier/model -> Core ML -> watch bundle
```

## Modules and contracts
- `MotionSource` produces `MotionSample(timestampMonotonic, accelerationXYZ, rotationXYZ, gravityXYZ?, orientation?, qualityFlags)` independent from Core Motion API; `MockMotionSource` for deterministic replay.
- `ExerciseClassifier.classify(window, context) -> Prediction(label, confidence, alternatives, modelVersion)`; include `unknown` class and calibration state. Plan context supplies priors, never a hard filter.
- `RepCounter.ingest(sample, selectedExercise) -> RepEvent?`; a full rep requires cycle transitions, duration limits, and debounce; quality checks reject gaps/unreliable orientations. Manual count edits produce correction events.
- `SetDetector.ingest(repEvents, activity, manualControls) -> SetTransition?`; state machine described below.
- `WorkoutRepository` persists entities and immutable domain events; correction events apply to materialized projection without losing originals.
- `SyncTransport` idempotent commands and events with UUID message IDs, device ID, monotonic sequence, schemaVersion, sentAt, sessionId. Never use wall-clock alone for ordering.
- `RestScheduler` uses absolute end timestamp, user settings, and manual overrides; survives app state changes as supported by platform. Haptics are best-effort and never the only signal.

## State machine
```text
idle -> preparing -> trackingSet -> candidateSetEnd -> resting -> trackingSet -> ...
                         |                  |           |
                         v                  v           v
                       paused <------------+--------- paused
                         \                                /
                          ------------> finished <-------
```
- `candidateSetEnd` after motion pauses; move to `resting` only after configurable hysteresis and evidence of completed reps OR manual finish.
- Last-rep timestamp sets rest start; do not reset rest due to delayed classification.
- Resume movement during candidate-end may return to tracking rather than finish set.
- Manual override always takes precedence; no duplicate set on rapid taps.
- User may start next exercise out of template order, changing active context only after confirmation/confidence rules.
- `finished` flushes event journal and schedules sync; if storage fails display error and do not claim saved.

## Data schema (v1, explicit IDs)
- `ExerciseDefinition`: id, name, movementCategory, supportedAutoRecognition, isCustom, createdAt.
- `WorkoutTemplate`: id, name, goal, ordered `TemplateExercise` entries.
- `TemplateExercise`: id, exerciseId, targetSets, repMin, repMax, initialRestSeconds, position, preferredWeightUnit.
- `WorkoutSession`: id, templateId?, startedAt, endedAt?, timeZoneAtStart, originDeviceId, status, planSnapshotVersion.
- `ExercisePerformance`: id, sessionId, exerciseId, positionObserved, labelSource(manual|model|confirmed), modelVersion?, confidence?, startedAt?, endedAt?.
- `SetRecord`: id, performanceId, index, reps, weightValue?, weightUnit, startedAt?, endedAt?, restStartedAt?, restSeconds?, repsSource, confirmed, userNotes?.
- `WorkoutEvent`: eventId, sessionId, deviceId, sequence, recordedAt, eventKind, typedPayload, supersedesEventId?, schemaVersion.
- `UserSettings`: goalDefault, units, autoRecognition, haptics, sound, rawSensorRetention, preferredRestByGoal.
- `ModelMetadata`: identifier, version, trainedClasses, watchValidatedClasses, autoEnabledClasses, perClassMetrics, samplingHz, windowLength, requiredChannels, evaluationSummary, provenance.
- `MotionRecording` (debug/consented): id, sessionId, startedAt, samplingStats, fileLocation, retentionPolicy, userConfirmedLabel?.

All domain types must support stable serialization. Store weight in a canonical unit internally (e.g. kg) and retain chosen display units to avoid conversion drift. Estimated 1RM only when valid for exercise and reps range; no medical or body-composition claims. Capture correction provenance.

## Motion + ML policy
1. Sample target 50 Hz where supported; record actual timestamps and gaps, avoid treating requested sampling as guaranteed.
2. Collect processed gravity-compensated acceleration and rotation rate when feasible; preserve consistent units and axis definitions. Document that data from MM-Fit (different watches) is not interchangeable without validation.
3. Sliding window baseline: 3–5 s window, 0.5–1 s step. For early prototype use motion-energy gate + filtered peak-based rep cycle with exercise-specific thresholds; allow offline replay.
4. For model: train a compact 1D CNN/TCN in Python with subject-held-out splits and class balance measures; convert via coremltools; benchmark watch inference cost and only then enable on-watch classification.
5. Core ML classifier must have deterministic fallback when model absent, malformed, unavailable or uncertain; never ship a placeholder masquerading as a learned model.
6. Separate activity classification, exercise classification, repetition counting and set lifecycle. Their confidence values and thresholds should be independently tunable and covered by replay tests.
7. Store derived events by default, not continuous raw IMU. Debug exports require opt-in, expiration and explicit user action.

## WatchConnectivity and data integrity
- Watch records all confirmed set transitions locally first, then queues sync. Phone merges based on `eventId` and `sessionId` with idempotent reconciliation.
- `sendMessage` may be used for reachable live display updates, not reliable persistence. Use queued/background-appropriate transfers for durable payloads; test real paired devices. `transferUserInfo` is not supported in Simulator for end-to-end transfer validation.
- Do not transmit sample-by-sample IMU continuously as V1 default. Exchange compact events and summaries; debugging motion transfer opt-in only.
- On conflict, preserve explicit manual corrections over raw model outputs and avoid silent last-write-wins on edits.
- Use monotonic timestamps for motion within a session and wall-clock timestamps for user-facing history; reconcile clock drift carefully.

## Permissions / platform lifecycle
- HealthKit requested only for workout integration/HR as needed; no core rep-detection dependency on approval. Consult current Apple requirements for workout processing/background behavior.
- Core Motion sampling, Watch background workout behavior, haptic/notification delivery, and screen locking must be tested on hardware.
- If health authorization is denied, manual logging remains usable; watch workout sessions may require permissions/platform capabilities and must report unsupported states clearly.
- Explicitly stop sensors, close sessions, and persist records on end/cancel/restart. Implement safe recovery for watch process termination.

## Broad exercise recognition protocol
1. Create `ml/exercise_inventory.csv` (or equivalent) by programmatically inspecting every eligible source file: source, label, normalized name, subject/session counts, watch/arm placement, samples, rest/unknown negatives, set-level rep annotations, license state, and eligibility flags.
2. Normalize exercise names cautiously. Similar names are not automatically identical (e.g. seated vs standing press, barbell vs dumbbell variants). Keep provenance and source-specific aliases.
3. Split by subject, then ensure session/window independence and avoid calibration data contamination. RecoFit uses different arm placement from the Apple Watch; evaluate as separate-domain pretraining or baseline, not direct evidence of Watch accuracy.
4. Compare a simple engineered-feature baseline with compact CNN/TCN. Train across eligible classes, record class imbalance and calibration, and evaluate each class plus unknown/nonexercise negatives. Benchmark model size, inference latency and power on SE 2 when possible.
5. Define `ExerciseSupportTier`: `candidate`, `trained`, `watchTested`, `autoEnabled`, `manualOnly`. Only transition to `autoEnabled` with logged measured per-class criteria and real Watch evidence. `unknown` rejection is required.
6. Report distinct counts: dataset candidate classes, usable classes, model output classes, classes tested on real Watch, and classes allowed to auto-log. If poor coverage, split models by sensor placement, exercise category, or optional plan-aware candidates without hiding failures.
7. Keep all exercises manually selectable, irrespective of the classifier output space.

## ML dataset and evaluation
- Candidate: MM-Fit `https://mmfit.github.io/`, `https://github.com/KDMStromback/mm-fit`; participant/session identifiers, watch motion, set labels and rep totals. Verify dataset access terms before redistributing or commercial training.
- Candidate: Microsoft RecoFit `https://github.com/microsoft/Exercise-Recognition-from-Wearable-Sensors`; research baseline with arm-worn sensor domain shift.
- Data labels normally give set-level counts, **not** exact timestamps of each complete rep. Do not falsely train a supervised per-rep event model from unobserved timestamps; use count estimation, signal peak heuristics, or a small human-annotated event dataset.
- Evaluate on held-out people and collected Apple Watch sessions; report exercise confusion matrix, unknown-class false positives, MAE reps per set, set-boundary timing, battery and latency. Lock and version splits.

## Repo structure proposal
```text
Raydiun.xcodeproj/
iOS/{App,Features,Data,Resources}/
Watch/{App,Features,Motion,Workout,Data}/
Shared/{Domain,Algorithms,Infrastructure}/
Tests/{DomainTests,ReplayTests,SyncTests,UITests}/
ml/{README.md,requirements.txt,src,tests,artifacts/.gitkeep}/
fixtures/{README.md,synthetic/}
docs/{PRODUCT.md,ARCHITECTURE.md,DECISIONS.md,ML_COVERAGE.md,privacy.md,hardware-test-plan.md}
AGENTS.md README.md TASKS.md
```

## ADRs needing deliberate decisions
- watch-side journal implementation and iPhone storage choice;
- exact iOS/watchOS targets given owned Watch hardware;
- use of `HKWorkoutSession` and permission fallback;
- exercise dataset/license suitability;
- model sampling/windows/thresholds after measured tests;
- correction merge policy and raw sample retention.
