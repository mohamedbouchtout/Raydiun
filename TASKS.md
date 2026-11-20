# TASKS.md — Build Plan and Executable Checklist

> Agent rules: read [AGENTS.md](AGENTS.md), [PRODUCT.md](docs/PRODUCT.md), [ARCHITECTURE.md](docs/ARCHITECTURE.md), [ML_COVERAGE.md](docs/ML_COVERAGE.md), and [DECISIONS.md](docs/DECISIONS.md). Complete P0 tasks in order. Each checked task needs commit/change summary, build/test evidence, known limitations. P1 cannot be described as ready while P0 is incomplete. Tasks are intentionally sized for incremental Codex runs. **All tasks start unchecked.**

## Phase 0 — Environment and repository foundation (P0)
- [ ] **P0-01: Inspect developer environment.** Run `xcodebuild -version`, list simulators, inspect existing repo/project and targets, confirm hardware dependencies. Record actual findings in [DECISIONS.md](docs/DECISIONS.md). **Done:** environment recorded; no imaginary targets/schemes.
- [ ] **P0-02: Scaffold Xcode project.** Create native SwiftUI iOS + watchOS apps, shared Swift module/package or shared source targets, unit/UI tests, assets, gitignore and coherent app naming. Configure target membership and entitlements only as needed. **Done:** both targets build for available generic simulator destinations (or documented SDK blocker), clear run instructions.
- [ ] **P0-03: Domain entities and serialized events.** Implement definitions from [ARCHITECTURE.md](docs/ARCHITECTURE.md) with stable UUIDs, source/confidence provenance, unit-safe weight conversion, versioned event serialization. **Done:** unit tests for decoding, weight conversion, ID uniqueness, and migration/version rejection.
- [ ] **P0-04: Design system and navigation skeleton.** iPhone Today/Templates/History/Progress/Settings tabs and Watch Start/Active/Rest/Summary states. Use mock data explicitly labeled `Preview` only. **Done:** navigable simulator UI, VoiceOver labels, screenshots optional, no live-data claims. **Stop for user review after this task.**

## Phase 1 — Working workout logger without ML (P0)
- [ ] **P0-05: Workout template CRUD.** Add/edit/delete templates, exercise selection, target sets/rep range/rest duration, arbitrary exercise order, goal settings. Persist changes across relaunch. **Done:** CRUD integration tests; empty/cancel paths work.
- [ ] **P0-06: Editable exercise library.** Seed initial built-ins and supported status; add/edit custom exercises with unique IDs; no custom recognition claim. **Done:** custom moves appear in plans and manual logging, proper duplicate-name behavior.
- [ ] **P0-07: Manual workout session engine.** Start/pause/resume/finish sessions, choose/reorder exercises during session, add/edit reps and weights, finish sets, skip/undo last entry. **Done:** deterministic domain state tests incl double taps, out-of-order and interrupted transitions.
- [ ] **P0-08: Persistent event journal.** Durable writes as each set completes, materialized workout projections, correction events, safe recovery on app restart. **Done:** crash/relaunch tests; corrections survive; no duplicate records.
- [ ] **P0-09: Watch workout UI + controls.** Implement usable standalone start/tracking/manual set/rest/finish screens with large controls and permission/error fallbacks. **Done:** manually log several sets on watch simulator and verify local retention.
- [ ] **P0-10: HealthKit workout lifecycle.** Integrate authorized `HKWorkoutSession`/builder when supported; manage pause/resume/end, background expectations, denied permissions. Test physical Watch. **Done:** authorized happy path and denial path; actual Apple Health write behavior documented.
- [ ] **P0-11: Rest engine and haptics.** Goal-based configurable presets, per-exercise override, rest from last-rep/manual completion timestamp, start/skip/extend/end, notification/haptic best effort. **Done:** clock-injected timer tests; rest persists across UI navigation; real-device haptic test recorded.

## Phase 2 — Motion sensing, replay, counting (P0)
- [ ] **P0-12: MotionSource abstraction.** Define protocol, timestamped sample type and mock replay; test sample sorting, units, out-of-order and missing data. **Done:** replay emits deterministic same values regardless of wall-clock.
- [ ] **P0-13: Real Watch motion capture.** Implement Core Motion only during active workout; target 50 Hz where supported; record actual rate, dropped samples, orientation, power state where available. Build diagnostics screen behind developer flag. **Done:** physical Watch capture/stop test and exported sample schema; no background data collection outside workout.
- [ ] **P0-14: Signal pipeline.** Build windowing, filtering, smoothing, calibration and quality checks; configurable exercise-specific settings. **Done:** unit tests with synthetic sinusoid, stillness, signal gaps and abrupt movement.
- [ ] **P0-15: Activity gate.** Classify movement/rest/unknown using interpretable rules before any neural model; conservative thresholds. **Done:** replay tests prevent ordinary hand movement from making sets; recorded false positives.
- [ ] **P0-16: Baseline rep counter.** Debounced cycle/peak detection with minimum/maximum rep duration and full-cycle requirement; per-exercise config; manual correction. **Done:** reproducible fixtures for 0,1,10 reps, slow reps, pauses, random shakes, duplicates, motion gaps; report MAE not just demo visuals.
- [ ] **P0-17: Set boundary detector.** Hysteresis and last-rep timestamp, pause vs end discrimination, explicit user override; prevent phantom sets, double counts, and accidental rest. **Done:** state-transition tests for >=8 edge cases; manual finish always works.
- [ ] **P0-18: Watch live instrumentation.** Show current rep/set/elapsed/rest + inferred status, manual select/confirm and fallback when unknown. **Done:** full replay integration can create and correct sets; UI indicates inferred versus confirmed values.

## Phase 3 — Broad-coverage research and Core ML (P0 for this prototype; no predetermined exercise-count cap)
- [ ] **P0-19: Broad dataset audit and exercise inventory.** Inspect actual MM-Fit and RecoFit files, plus carefully vetted optional datasets; enumerate **every available exercise class** and normalize carefully. Record official download URLs, licensing/restrictions, sensor placement, subject and session coverage, label granularity, and eligible classes. Exclude datasets without suitable permission. Never commit raw datasets by default. **Done:** `ml/README.md`, `ml/exercise_inventory.csv`, coverage summary and provenance manifest; show counts of candidate vs usable classes; no imaginary per-rep timestamps.
- [ ] **P0-20: Reproducible ETL.** Download instructions (not automated if license prohibits), normalization, resampling, feature extraction, subject/session split, checksums and artifacts metadata. **Done:** tests for tensor shape, leak-proof split and label consistency; seeded run reproducible.
- [ ] **P0-21: Classical baselines.** Train a classical baseline across **all eligible dataset classes** (not just three) + rest/unknown negatives where available; analyze whether category-specific models outperform one giant classifier. **Done:** per-class precision/recall and confusion matrix on unseen subjects; report domain shift.
- [ ] **P0-22: Small temporal network.** Train and compare compact 1D CNN/TCN across the maximum viable audited classes; fixed tensor/channel contract, calibration, explicit unknown rejection, per-class support tiers, confusion/abstention metrics, reproducible model export. **Done:** held-out evaluation and logged errors; only choose NN if demonstrably useful.
- [ ] **P0-23: Convert and benchmark Core ML.** PyTorch -> Core ML with `coremltools`, compare predictions to Python fixtures; benchmark watch memory, battery and per-window latency on SE 2 where available (otherwise mark unverified); graceful fallback. **Done:** conversion parity threshold documented and measured real-device profile.
- [ ] **P0-24: Exercise inference integration.** Watch-side classifier interface, real model load, top-k/unknown confidence, fallback if unavailable. Distinguish simulator/replay and real sessions. **Done:** replay integration on **all eligible classes**, with first real-device smoke tests for curls, shoulder press, squats and progressively expanded classes; unsupported classes remain manual.
- [ ] **P0-25: Plan-aware recognition.** Apply calibrated plan priors and remaining planned exercise context, but allow unexpected/unknown and user selection. **Done:** tests for ordinary order, out-of-order, unplanned exercise and manual override; confusion rates compared against baseline.
- [ ] **P0-26: Real Apple Watch validation set.** Opt-in recordings from multiple wearers/sessions with manually verified ground truth; test different speeds, handedness, other movements and exercise variations. **Done:** report per-class metrics and a registry with counts for dataset/trained/watch-tested/auto-enabled; downgrade classes that fail. Distinguish unavailable SE 2 testing from results from other models.

## Phase 4 — Watch ↔ iPhone synchronization and workout records (P0)
- [ ] **P0-27: WatchConnectivity protocol.** Versioned messages, ids, sequence, retries, queued completed events and live ephemeral states; device disconnect handling. **Done:** integration/unit tests for duplicates, reordered arrival and stale message versions.
- [ ] **P0-28: Phone reconciliation.** Merge Watch events into local store, preserve explicit corrections and provenance, present offline/sync indicators. **Done:** forced disconnect/reconnect test on paired hardware and zero duplicate sets.
- [ ] **P0-29: Workout history.** Detail/edit view, filters, status, exercises/sets/weight, export as CSV/JSON with units and provenance. **Done:** corrected history recomputes and export round-trip test.
- [ ] **P0-30: Exercise analytics.** Charts for per-exercise top sets, volume, session frequency, estimated 1RM with strict applicability/estimate labeling; overall progress rollup. **Done:** tested formulas and charts for sparse/noisy/no-history scenarios.

## Phase 5 — Explainable recommendations (P0)
- [ ] **P0-31: Goal settings and rest preset rules.** Strength/hypertrophy/endurance selectable; default per-exercise rest preset; manual override, no physiologic diagnosis. **Done:** rule tests and transparent reason labels.
- [ ] **P0-32: Progressive overload rules.** Based only on confirmed, comparable sets and target rep ranges, suggest small weight or rep changes when enough sessions exist. Never auto-change an existing template. **Done:** tests for improvement, plateau, skipped session, changed machine/equipment, insufficient data and mixed units.
- [ ] **P0-33: Recommendation UI.** Per-exercise next-workout suggestions with reason and explicit accept/dismiss. User changes are stored, undoable. **Done:** no recommendations based solely on unconfirmed inferred sets.

## Phase 6 — Prototype validation gate (P0; production gates noted but not claimed complete)
- [ ] **P0-34: Unit/integration/UI test coverage.** Exercise + rep boundary edge cases, domain serialization, sync idempotency, permissions denied, offline mode, interruptions, dark mode, accessibility. **Done:** tests pass in available build infrastructure; documented device-only coverage.
- [ ] **P0-35: Usability and field validation.** Prototype smoke tests with available wearers; >=5 people x >=3 sessions reserved for later beta readiness if recruiting possible; compare ground-truth rep counts, false starts, latency, correction burden; revisit product thresholds. **Done:** written results and blocker list; never claim those tests were run without evidence.
- [ ] **P0-36: Security/privacy/retention.** No unapproved endpoints, user data export/delete, raw motion only opt-in, review requested entitlements, appropriate App Store privacy disclosures and HealthKit requirements. **Done:** manual privacy audit checklist and tests of deletion/export.
- [ ] **P0-37: Performance + device matrix.** Profile typical 45–60 minute Watch workout for CPU, memory, battery and end-to-end response on oldest targeted Watch; record OS/device combinations. **Done:** actual measured report or mark release blocked.
- [ ] **P0-38: Prototype demo polish.** Onboarding, permission explanations, clear unsupported exercise behavior, recovery flows, loading/errors, build/run docs and prototype reproducibility checklist and later TestFlight gaps list. **Done:** complete end-to-end walkthrough on physical paired devices, stable demo build; production gaps clearly named.

## Phase 7 — Post-prototype stretch (P1; not required for first demo)
- [ ] **P1-01: Labeled custom exercise capture.** Opt-in recording of several examples with explicit identity and rep totals; preview/review/delete/export; no pretending custom exercises are recognized yet.
- [ ] **P1-02: Similarity-based custom recognition proof of concept.** Compare embeddings/DTW to labeled examples, per-user thresholds and unknown rejection, no silent training; evaluate on new sessions and hard negatives.
- [ ] **P1-03: Personalized motion profiles.** Learn from manually confirmed samples only, opt-in reset, versioned profiles; measure improvement against nonpersonalized baseline.
- [ ] **P1-04: Adaptive rest experiment.** Estimate recommended rest based on goal, load, and previous performance, validate usefulness and false certainty; heart rate remains auxiliary, not source of rep counts.
- [ ] **P1-05: Camera-assisted leg exercise feasibility.** Research opt-in pose tracking for leg extensions/curls, angle/occlusion limitations, privacy and setup burden; prototype separately before adding to main app.

## Prototype-specific additional ML tasks (do before enabling broad auto-recognition)
- [ ] **P0-ML-A: Label inventory and taxonomy.** Generate a machine-readable table of all classes available from permitted datasets, with sensor placement and subject/sample counts, plus ambiguous/excluded mappings. **Done:** deterministic script recreates inventory from files; licensing and representation gaps recorded.
- [ ] **P0-ML-B: Candidate model breadth experiment.** Compare all eligible class labels to a grouped/category hierarchy; keep unseen exercise negatives and evaluate top-k vs abstention. **Done:** subject-disjoint per-class metrics, grouped confusion matrices, macro metrics and a coverage table; no cherry-picked accuracy.
- [ ] **P0-ML-C: SE 2 exercise support registry.** Make a generated data file consumed by app/replay listing per-class state (`candidate`, `trained`, `watchTested`, `autoEnabled`, `manualOnly`) and experiment reference. **Done:** no class becomes auto-enabled without Watch-specific evidence; UI exposes manual fallback.
- [ ] **P0-ML-D: Prototype demo acceptance.** On actual watch if available, start a workout, recognize at least one **validated** exercise, count and correct reps, finish a set, get rest haptic, sync and view history. **Done:** recorded test evidence or clearly documented hardware blocker; number of other experimental classes reported separately.

## Suggested first Codex prompts
### Prompt 1 — scaffold
`Read AGENTS.md, docs/PRODUCT.md, docs/ARCHITECTURE.md, docs/DECISIONS.md, and TASKS.md. Implement P0-01 through P0-04 only. Before coding, inspect local Xcode and existing files. Create both iOS/watchOS targets with a testable domain layer, run builds on available simulator destinations, update TASKS.md with actual evidence, and report blockers. Do not use a simulated ML model as live detection. Stop after P0-04.`

### Prompt 2 — manual end-to-end functionality
`Continue with P0-05 through P0-11 in order, with tests after each stage. Make manual workout logging and a watch rest timer reliable before adding ML. Follow privacy, persistence and correction requirements in AGENTS.md. Do not skip unsuccessful builds.`

### Prompt 3 — rep detection
`Implement P0-12 through P0-18. Use deterministic fixtures and real Core Motion behind an interface. Quantify rep errors with replay tests. Don't call demo sensor input real recording, and don't auto-count exercises for which evidence is inadequate.`

### Prompt 4 — real ML
`Implement P0-19 through P0-26, first auditing dataset licenses, labels and domain shift. Build reproducible Python training and evaluation on held-out participants, compare baseline and 1D CNN across every eligible exercise class, publish a per-class support registry, convert tested model to Core ML, then run on physical Apple Watch SE (2nd generation, 2022) if available. Report measured accuracy; otherwise mark hardware verification blocked.`

### Prompt 5 — product completion
`Implement P0-27 through P0-38, ensuring durable offline watch event synchronization, correction-aware exercise analytics, explainable progression suggestions and actual device QA. Don't claim beta readiness if physical-watch tests or the release gates are incomplete.`

## Progress log template (append after each agent session)
| Date | Tasks attempted | Evidence (commands / actual devices) | Outcome | Remaining blockers |
|---|---|---|---|---|

## Owner hardware acceptance gate — Apple Watch SE (2nd generation, 2022)
- [ ] **HW-SE2-01:** Record exact iPhone model, watchOS/iOS versions, Xcode version, pairing status and signing team. Never assume the Watch is running a particular watchOS version.
- [ ] **HW-SE2-02:** Build and deploy the Watch target to the physical SE 2, confirm permissions and a HealthKit workout session, and verify motion XYZ and rotation rate samples with timestamps.
- [ ] **HW-SE2-03:** Profile at least one representative 30-minute workout: actual sampling rate and gaps, Watch battery delta, CPU/memory where tooling allows, haptic rest-end alert, and connectivity interruptions.
- [ ] **HW-SE2-04:** Run Core ML parity/inference benchmarks on the SE 2; if watch-side inference is too costly, document a phone-inference prototype fallback without fabricating watch-side results.
- [ ] **HW-SE2-05:** Only mark classes `watchTested` or `autoEnabled` with actual SE 2 evidence and manually verified labels.
