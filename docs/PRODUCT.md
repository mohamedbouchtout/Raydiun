# PRODUCT.md — Raydiun Prototype Product Requirements

**Owner hardware:** Apple Watch SE (2nd generation, 2022), paired with a compatible iPhone. Prototype acceptance requires actual-device testing; simulation alone is insufficient.

## Product promise
Start a planned strength workout on Apple Watch, let the watch recognize supported exercises and repetitions with minimal input, receive rest haptics, and review real, editable training progress on iPhone. The app becomes more useful with confirmed exercise history, without falsely claiming perfect recognition.

## Target user
The immediate development milestone is a working technical prototype for an owner of Apple Watch SE (2nd generation, 2022) and a compatible paired iPhone. Do not spend prototype time on App Store compliance work unless it blocks real device builds.
An iPhone + Apple Watch owner doing 2–6 strength sessions/week who wants fewer interactions than a typical manual workout log. Gym strength and hypertrophy workflows first; cardio, competitive powerlifting programming, and advanced medical recovery are out of scope.

## Prototype scope (working-demo definition, NOT App Store shipping readiness)
- iPhone: create/edit workout templates; reorder exercises; specify target sets/reps/rest; choose a goal (strength/hypertrophy/endurance); view active workout status, exercise history, charts, and personal bests; log/edit weight/reps/exercise after the fact.
- Watch: start/pause/resume/end workout; show current recognized exercise, count, set, and rest timer; manually select an exercise; manual + automatic finish-set/start-rest; haptic when rest ends; standalone during phone disconnection.
- Motion: user-initiated recording, supported exercise recognition using IMU, rep counter, confidence/unknown fallback, set boundary state machine, local reliable session record.
- Plan-aware recognition: exercise candidate priors derived from today's template while honoring out-of-order movements and manual overrides.
- Progress: per-exercise weights, reps, sets, total volume (sum of load × completed reps), estimated one-rep max **clearly labeled as estimate** where appropriate, recent consistency. Charts must have empty states.
- Recommendations: transparent deterministic rules for next weight/reps based on user's logged history and goal, never claiming to be an intelligent learned coach yet. User must explicitly accept changes to future plans.
- Rest: configurable baseline presets by goal/exercise, manual override, countdown in background as platform allows, haptic notification; not inferred physiological readiness.
- Exercise library: built-in supported/unsupported tags; user-defined exercises can be manually logged in V1. Recording labeled custom demonstrations is an **experimental opt-in**, not automatic self-training in shipped V1.

## Exercise coverage and validation policy
- **Candidate recognition coverage:** audit all usable exercise labels in MM-Fit, RecoFit, and optionally further properly licensed datasets; produce a source-to-canonical-label map and train/evaluate the largest viable set. The exact number must be derived from inspected files, not promised in advance.
- **First pipeline smoke tests:** bicep curl, shoulder press, squat, plus rest/unknown (where source labels allow). These are not the overall class limit.
- **Validated auto-logging:** permit only exercise classes passing class-specific validation on Apple Watch SE (2nd generation, 2022) with acceptable confusion, unknown false positives, and rep-count performance; other trained classes may appear as suggested/experimental only.
- **Always manually loggable:** all built-in and user-created exercises, including stationary-wrist leg press/leg extension/hamstring curl.
- Maintain a visible support registry: `candidate` → `trained` → `watch_tested` → `auto_enabled` (or `manual_only`). The app must not auto-log unvalidated classes.

## Prototype out of scope
- Automatically understanding arbitrary custom exercises with zero examples.
- Training a personalized neural network silently on guessed labels.
- Automatic load recognition, camera pose tracking, location/gym occupancy, social feed, subscriptions, cloud accounts, Apple Health workout recommendations, automatic injury/form diagnosis, RPE inferred from HR, true muscular recovery prediction.
- Guaranteed rep counting for stationary-arm leg machines.

## User journeys
### A — planned workout
1. On iPhone create `Push Day`: 3 × 10 curls, 3 × 8 shoulder press, 3 × 10 squat (demo plan may be unrealistic but illustrates sequence).
2. Start session on Watch; optionally select template. HealthKit permissions requested contextually.
3. Start any planned exercise; show proposed label when confident. User confirms/corrects when uncertain.
4. Completed rep updates count; start/end of set auto suggested/detected with clear manual fallback.
5. Rest countdown begins from last rep; user changes rest length or skips; Watch haptic at zero.
6. Next exercise may be any planned item; don't force sequence.
7. End workout; summary survives offline and syncs to iPhone when available.
8. Edit weights or incorrect rep counts; historical charts and recommendations recompute.

### B — no wearable inference
User selects any exercise and enters set, reps, weight manually. App remains fully usable without detection or HR permissions.

### C — failure/recovery
Watch loses connection or app exits: confirmed sets remain locally durable and sync idempotently; on restart provide recovered workout with clear indication if the last active interval was not captured.

## UX screen inventory
- iPhone: Today/Start, Workout Templates list/editor, Workout Live Summary (read-only + controls where reliable), History, Workout Detail/Edit, Exercise Detail/Charts, Progress Overview, Settings/Privacy, Debug Replay (developer build only).
- Watch: Start Workout, Active Set, Unknown Exercise/Choose, Rest Countdown, Workout Summary, Connection/Recovery, Permissions.
- Always show which numbers are inferred vs manually confirmed when relevant. Provide large Watch touch targets, VoiceOver labels, high contrast, and no sound-only alerts.

## Recommendation rules (initial illustrative defaults; configurable)
- Goal strength: default rest 180 s for compounds, 120 s isolation; hypertrophy: 120 s compounds, 90 s isolation; endurance: 60 s compounds, 45 s isolation. These are UX defaults, not universal physiology.
- Double progression: if user reaches top of target rep range across target sets in two comparable sessions, suggest the smallest configured weight increment; otherwise maintain. Suggest reduction only with explicit explanation, and don't auto-edit a plan.
- Avoid comparing different machines as if load resistance were identical. No recommendation without sufficient confirmed history.

## Nonfunctional / trust requirements
- No account needed. Local-first and offline usable.
- Settings allow disabling automatic recognition, raw-data capture, haptics, sound; secure export/delete controls.
- Recording starts/stops within explicit workout lifecycle; readable permission explanations and denial fallback.
- Data persisted incrementally; when backgrounded, failures handled honestly.
- Accessibility, reduced-motion preferences, and privacy policy text before public distribution.

## Success metrics / gates (targets to validate, not claims)
- Prototype field test: collect at least one real paired Apple Watch session across several exercise categories; aim for >=5 participants × >=3 sessions for *later beta readiness*, not as a prerequisite for an internal replay demo.
- Rep counting: median absolute set error <=1 rep for supported exercises on held-out real-watch test sets; report per-exercise error distribution and worst cases.
- Exercise classifier: report per-class precision, recall, confusion and support count with held-out-person/session evaluation; target >=90% balanced accuracy for any auto-enabled class group **only if supported by data**. Otherwise downgrade individual classes to experimental/manual. Test unknown/nonexercise false activations separately. No universal accuracy claim.
- Set end detection: >=95% of user-observed ends recoverable via automatic or one-tap override; median delay <=5 s (measure false-positive rate).
- Offline resync: zero duplicates in forced-disconnect integration test.
- Battery / CPU budgets: set measurable thresholds after profiling on lowest supported Watch; don't ship without actual hardware measurement.

## Product differentiator: later V2
- Teachable custom exercises: user records 3–10 **labeled and confirmed** sets; compare embeddings against user-specific examples; opt-in personalization, validation across sessions, easy reset, unknown fallback.
- Performance-adaptive rest using confirmed past session performance, not heart rate alone.
- Optional camera-assisted leg day and load scanning, pending explicit user research and experiments.
