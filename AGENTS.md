# AGENTS.md — Instructions for Codex and other coding agents

**Owner test device (confirmed): Apple Watch SE (2nd generation, 2022), S8 SiP.** Build first for this hardware, and do not assume ECG, wrist-temperature, or newer-model-only APIs. Capture actual watchOS and iPhone pairing details when device setup begins.

## Mission
Build **Raydiun** (working name), an offline-first iPhone + Apple Watch strength-workout tracker. The watch records movement and attempts recognition across as many research-dataset exercises as evidence supports; automatic logging is enabled only for validated classes. It counts repetitions and sets and manages rest with haptics. The iPhone builds plans, stores history, permits correction, and presents progress. See `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/ML_COVERAGE.md`, and `TASKS.md` before changing code.

## Operating rules
1. **Work in small, testable increments.** Choose the next unchecked task in `TASKS.md`, state what you will do, implement, test, and update its status. Do not mark a task complete without its acceptance criteria and evidence.
2. **Build truthfully.** Never simulate a Core Motion stream, Apple Watch detection, model inference, or workout completion while presenting it as live. Clearly label demo/replay/mock modes. Avoid fake accuracy metrics, demo data presented as real, and claims of medical-grade recovery measurement.
3. **Confirm platform APIs** against installed Xcode SDK and current Apple documentation. Never invent Swift APIs, entitlements, platform support, or background-execution guarantees. Ask for user input only for genuine blockers such as signing credentials, device availability, and package identifiers.
4. **Keep it compilable.** After every stage, run the relevant `xcodebuild`/Swift tests and fix errors. If Xcode, signing, or physical devices are unavailable, report exactly what was and wasn't verified. Do not claim physical-device validation from simulator tests.
5. **Privacy-first.** Workout logs and raw motion data stay on device by default; recording begins only during an explicitly started workout or opt-in calibration. No analytics SDK, backend, account requirement, or external API in V1. Don't upload health or motion data. Make debug raw-sensor export opt-in.
6. **No unsafe automation.** Avoid asserting that an exercise/rep has occurred when confidence is low. The user can always edit exercise, reps, sets, and weights, stop tracking, and override rest states.
7. **No irreversible actions.** Don't delete user workout history or overwrite manually corrected data. Use schema migrations for data changes. Don't commit keys, provisioning profiles, raw personal workout logs, or large datasets.
8. **Respect battery and performance.** Sensor sampling is workout-scoped, throttled/disabled outside sessions, and measured on real hardware before release.
9. **Preserve evidence.** Tests and screenshots should be genuine. Document model provenance, dataset licensing, pre-processing, evaluation split, and version/hash; prohibit training/test leakage by person/session.
10. **Scope discipline.** Finish V1 P0 items before adding generative AI, subscriptions, social features, camera tracking, adaptive HR rest, or unsupported universal exercise recognition claims.

## Technical baseline (adjust only if justified)
- Apple platforms: Apple Watch SE (2nd generation, 2022) is the owner’s physical test device; target iOS 17+ / watchOS 10+ provisionally, with final deployment choices based on the actual paired phone, OS version, and installed Xcode SDK. Use APIs available on the lowest supported Watch, and do not require newer watch hardware or Apple Intelligence. SwiftUI and Swift 6-compatible code.
- iPhone app: planning, history, charts, weights, review/corrections, settings, import/export.
- Watch app: workout session, motion acquisition, on-watch state/reps/rest UI, tactile notifications; independent of phone after session starts.
- HealthKit: `HKWorkoutSession`/`HKLiveWorkoutBuilder` when appropriate, after explicit authorization; do not require HR access to count reps; gracefully handle denial.
- Motion: `CMMotionManager` / `CMDeviceMotion`; record timestamp, user acceleration, rotation rate, and optional gravity/quaternion metadata. Start with 50 Hz target, log actual time gaps and device support.
- Inference: `ExerciseClassifier` protocol; deterministic heuristic baseline + offline replay first; optional small Core ML classifier trained externally. Run low-cost inference on watch once validated; **do not require live streaming of raw 50 Hz data to iPhone**.
- Storage: SwiftData for app-facing records if supported by tested targets; otherwise stable repository interfaces with a lightweight Codable/SQLite watch cache. Explicit UUIDs and timestamps; idempotent sync.
- Communication: WatchConnectivity; reliable queued transfers for completed sets/workouts and reachable messaging for immediate nonessential UI updates. Never depend on guaranteed instant watch/phone connectivity.
- Visualization: Swift Charts for iPhone progress; accessible labels and Dynamic Type.
- Python ML research: `ml/` with pinned environment, scripts, reproducible splits, model evaluation and Core ML export. Dataset coverage must be **maximized experimentally, not assumed**: audit all eligible class labels, create a coverage matrix, train and measure per class, and gate automatic logging per validated class.

## Architecture boundaries
- `Shared/Domain/`: platform-agnostic domain types, state machine, algorithms, contracts. No UI, `HealthKit`, `CoreMotion`, or platform-specific dependencies in pure unit-test modules.
- `iOS/`: SwiftUI screens, iPhone persistence, planning, charts and sync adapter.
- `Watch/`: workout lifecycle, motion acquisition, local detection pipeline, Watch UI and haptics.
- `Shared/Infrastructure/`: sync messages, serialization, storage adapters, time services.
- `ml/`: exploratory research and reproducible model artifacts. No downloaded dataset is committed by default.
- `Tests/`: deterministic unit, integration, replay and performance tests.

## Non-negotiable behavior
- Workout planner does **not** force a fixed order. Plan membership adjusts classification priors; never overrides clear contrary sensor evidence. Manual selection always available.
- Set start/end uses hysteresis and an explicit state machine, not a single instantaneous classifier threshold. Pause between reps must not double count sets. Every rep is counted at most once.
- Rest timer starts from the **estimated last-rep time**, not the later detection/confirmation time; adjustable preset and manual start/skip/end are always available.
- During session interruptions or reconnection, locally persisted set events replay idempotently; no lost, duplicate or reordered records.
- Weights are user entered and carried forward; watch sensors cannot determine the load accurately. Never imply automatic weight detection in V1.
- Unknown/unsupported exercise stays `unknown` or triggers a prompt, rather than inventing a label. A class present in a dataset is only a candidate; it becomes auto-loggable after Watch-specific evidence and threshold gates. Unsupported classes remain manually loggable.
- Corrections always override predictions, are auditably stored, and only enter personalized learning from explicitly confirmed labels.
- Repetition confidence ≠ exercise confidence; record both separately if supported.

## Prototype and broad-coverage rules
- This is a **working prototype**, not an App Store/TestFlight release commitment; prioritize executable Watch capture, real sensor pipelines, reproducible ML experiments, and live correction flows over launch polish.
- Attempt the **largest defensible number of exercise classes** from MM-Fit, RecoFit, and any newly vetted datasets, but track separate counts for (a) dataset classes, (b) trained classes, (c) validated-on-Watch classes, and (d) enabled auto-log classes. Never report one as another.
- The broad-class dataset experiment belongs in the prototype's core scope. Avoid labeling an exercise supported merely because it appears in training data; unknown rejection and real-device validation are mandatory for enabling auto-logging.
- Make the SE 2 the performance baseline. Validate power, inference latency and sampling on SE 2 if available; if only other models are available, state that SE 2 remains untested.

## Definition of done for a task
- Meets its acceptance checklist in `TASKS.md`.
- New code has relevant tests and handles empty/permission-denied/offline/error paths.
- Compiles for available targets; format/lint warnings addressed or documented.
- User-facing flows have accessibility identifiers, VoiceOver descriptions, and reasonable loading/error/empty states.
- `TASKS.md` updated with completion state, evidence (command/device), and remaining limitations; `docs/DECISIONS.md` updated for material architectural changes.

## Useful build commands (agent should inspect actual scheme names first)
```bash
xcodebuild -list -project Raydiun.xcodeproj
xcodebuild -project Raydiun.xcodeproj -scheme Raydiun -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Raydiun.xcodeproj -scheme RaydiunWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build
# Use an available simulator destination for tests after listing devices/schemes.
```
These are example commands, not proof of actual scheme names or successful builds.

## When uncertain
Prefer a working rule-based baseline with clear extension seams over an unverified ML promise. Put unknowns into `docs/DECISIONS.md`; record a short experiment and measured exit criterion before committing to complex solutions.

## First action for Codex
1. Read `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `TASKS.md`, and `docs/DECISIONS.md`.
2. Check Xcode version, available simulator targets, and whether a project already exists.
3. Implement **P0-01 through P0-04 only**, run builds, report results, and stop for review before continuing.
