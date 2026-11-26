# DECISIONS.md — Assumptions and Architecture Decision Log

## iPhone dock appearance

- The native tab layout comes from `slrky2/Raydiun`'s `iphone-workout-redesign-ci-fix` branch at `891a237`. iOS renders the bar with Today, Train, Coach, Log, and Progress. The tabs open the latest Raydiun screens, and Today’s header opens Profile beside Watch status.

## Assumptions for initial implementation
- Product and Xcode project name: **Raydiun** (user-confirmed).
- Single-user, English UI, iOS + watchOS, no account or server in V1.
- Target watch hardware: **Apple Watch SE (2nd generation, 2022)**; minimum deployment targets proposed: iOS 17 / watchOS 10, subject to paired iPhone and installed SDK compatibility verification. Benchmark on the actual Apple Watch SE 2 (2022); do not use Series 8 simulator performance as evidence.
- Units: lb/kg both supported; internal storage canonical kg.
- Automatic recognition scope: **as many eligible exercises as datasets support and real Apple Watch tests validate**. Curls, shoulder presses, and squats are an initial smoke-test subset, not a fixed cap. Train/evaluate across all audited eligible classes; enable automatic logging only for classes passing per-class criteria. Add `unknown/rest` negatives.
- All other built-in/custom exercises can be manually logged.
- Workout plans influence but don't dictate recognition; out-of-order permitted.
- User-entered weights, transparent suggestions; no automatic weight estimation.
- Prototype excludes camera, trained custom exercise recognition, and real-time cloud AI. Custom exercises remain manually loggable; custom recognition is a later experiment.

## Questions to settle when convenient (not blockers for scaffolding)
1. **Watch answered:** Apple Watch SE (2nd generation, 2022). Which paired iPhone model and actual watchOS/iOS versions are installed? Not a blocker for scaffolding.
2. **Answered:** development goal is a **working prototype**, not TestFlight or App Store release yet.
3. **Answered:** app name is **Raydiun**. Bundle ID uses temporary `com.example.raydiun` until a legitimate developer team identifier is supplied.
4. Should HealthKit workouts appear in Apple Fitness/Health by default after consent?
5. **Answered:** cover the maximum number of exercises supported by audited datasets and validated real-watch measurements; curls + presses + squats are merely smoke-test classes.
6. Any design/branding preference or should we use simple native SwiftUI styles?

## Locked prototype preferences (2026-11-20)
- Name: Raydiun.
- Goal: working prototype.
- Target Watch hardware: SE (2nd generation, 2022).
- ML objective: maximum practical audited exercise-class coverage, not a hard three-exercise limit.
- Do not conflate model class count with validated reliable auto-recognition count.

## Decisions
### ADR-001 — Watch-first, offline-first
**Status:** Proposed. Watch must not depend on phone presence to log a workout. Persistence precedes transmission.

### ADR-002 — ML is optional until proven
**Status:** Proposed. Use replayable heuristics and manual controls first. Enable Core ML only with real converted and evaluated model assets.

### ADR-003 — Explicit user corrections are authoritative
**Status:** Proposed. Corrections override inferred data and never serve as model training data without consent and validation.

### ADR-004 — Rest suggestions are goal-based, not physiological diagnoses
**Status:** Proposed. Start with explainable presets and logged-performance rules. HR alone never indicates rep completion or guaranteed readiness.

## Decision log template
- **ADR-ID / date:**
- **Context:**
- **Decision:**
- **Alternatives:**
- **Consequences:**
- **Validation/evidence:**

### ADR-005 — Owner hardware is Apple Watch SE (2nd generation, 2022)
**Status:** Confirmed by owner (2026-11-20). The SE 2 has an S8 SiP, accelerometer, gyroscope, and optical heart-rate sensor. Treat ECG, wrist-temperature sensing, and newer-model-only capabilities as unavailable or out of scope. Start with a configurable 50 Hz Core Motion sampling request and record **actual** observed rates. Measure sustained recording, battery, haptic alerts, foreground/background behavior, and Core ML inference latency on the physical SE 2. Do not assume a Neural Engine, high-frequency sensor entitlement, or unlimited background processing.

**Reference:** https://support.apple.com/en-us/111853

### ADR-006 — Phase 0 project and deployment targets
- Xcode 27.2 (27B52), with iOS and watchOS 27.2 device and simulator SDKs. The repository initially contained specifications and no Xcode project.
- Outside the workspace sandbox, `xcrun simctl list devices available` returned an empty device list. The sandbox itself could not connect to CoreSimulator.
- Minimums are iOS 17 and watchOS 10 for the Series 6–8 compatibility scope and the SE 2 physical baseline. The paired iPhone, installed device OS versions, and signing team remain unverified.
- SwiftUI iPhone app embeds a single-target SwiftUI Watch companion. Temporary bundle IDs are `com.example.raydiun` and `com.example.raydiun.watchkitapp`. Domain sources are shared with both apps and tested on macOS through SwiftPM. Source sharing keeps the domain Foundation-only.
- References: [Apple Watch compatibility](https://support.apple.com/en-us/118490) and [Apple single-target watchOS guidance](https://developer.apple.com/documentation/technotes/tn3157-updating-your-watchos-project-for-swiftui-and-widgetkit).
- Simulator runtime discovery outside the sandbox returned an empty runtime list. `xcrun devicectl list devices` reported no physical devices.

### ADR-007 — Version 1 workout event serialization
- The event envelope contains explicit UUIDs for event, session, and origin device, a device sequence number, a wall-clock timestamp, a typed payload, and an optional superseded event ID. The payload discriminator is the event kind.
- The decoder checks the schema version before decoding the payload. Version 1 is the first schema. Unsupported versions fail explicitly until a migration exists.
- Loads are encoded as kilograms alongside the chosen display unit. Exercise and rep provenance are separate, and a missing exercise ID represents an unknown exercise.

### ADR-008 — Local iPhone workout templates
- The iPhone planner stores the existing Codable template models in a versioned JSON file in Application Support. Writes replace the file atomically, and the list updates only after a successful write. A load error disables editing until the store can be read.
- The editor works on a draft and normalizes exercise positions on save. The starter picker assigns stable exercise IDs that the editable library can retain in P0-06. All starter exercises are manual-only.

### ADR-009 — Local iPhone exercise catalog
- The catalog combines the six starter exercises and locally saved custom exercises. Starter IDs retain their original values so existing templates resolve. A custom exercise keeps its UUID and creation date when edited. Templates resolve names from the catalog by ID.
- Custom definitions are stored in a separate versioned JSON file in Application Support. Writes replace the file atomically. A catalog load failure blocks edits and offers a retry.
- Names must be unique within the catalog after trimming leading and trailing whitespace and comparing case-insensitively. A custom exercise can change its own capitalization. All starter and custom entries are manual-only.

### ADR-010 — Raydiun iPhone theme and dashboard
- The owner’s light and dark Home mockups define the iPhone palette and layout. Both appearances share native SwiftUI components and follow the system appearance. Each tab has its own navigation stack. The Log tab opens Training Log, and Profile provides training setup, the walkthrough, and privacy settings.
- Home projects the existing local schedule and workout journal. Weekly plan fulfillment requires a finished session with confirmed sets on the scheduled date and a matching template ID. Streaks and weekly reps use finished sessions with confirmed sets, and historical loads use the most recent confirmed weighted set by exercise ID.
- The redesign needs no storage migration. The Watch status pill reports unavailable until a connection status source exists. The dashboard displays a previous user-entered load and omits estimated duration and target load until those values have a data source.

### ADR-011 — Local training setup and recurring splits
- First launch plays a bundled Raydiun mark animation before Welcome or Today. Returning installs with workout or template data open Today.
- Training setup stores answers, draft routine IDs, and walkthrough progress on the iPhone. It generates equipment-appropriate routines from the manual exercise catalog. Generated routines remain editable with the same template editor as other routines.
- A saved weekly split applies from its effective local date. Existing date-specific choices take precedence, and skipping a date suppresses that day's recurring workout. A later split version preserves earlier schedule lookups. Templates are upserted by draft ID before activation so the same save can be retried.
- The first-workout walkthrough advances using committed journal entries and selection of the Log tab. It uses the normal manual workout flow.
- Required Apple, Google, and email sign-up is deferred to a separate batch.
