# ML_COVERAGE.md — Raydiun broad-exercise prototype plan

## Objective
Try to recognize the **largest defensible set** of strength exercises represented in eligible public datasets. **Do not** equate the number of labels in a dataset with the number Raydiun can reliably auto-log on a wrist-worn Apple Watch.

## Hardware and prototype boundaries
- Target: Apple Watch SE (2nd generation, 2022), with SE 2 as the performance baseline where available.
- Run an offline Python training workflow and convert to Core ML. Prefer on-Watch inference if measured feasible; a phone-only inference prototype may be used temporarily but must be clearly labeled and must not require raw-stream networking/cloud.
- Validate the exact SE 2 hardware/OS available, including observed sensor rate, wrist placement, haptics, inference latency, and power; do not extrapolate from Series 8 benchmarks.
- Public recordings from different watches and forearm sensors may be useful for learning features but do **not** establish accuracy on Apple's wrist devices.

## Candidate sources (confirm availability and permitted use)
| Source | URL | Cautions |
|---|---|---|
| MM-Fit | https://mmfit.github.io/ | Smartphone / smartwatch / pose modalities may differ; check actual license, labels, and set-level counts. |
| MM-Fit code | https://github.com/KDMStromback/mm-fit | Code license and dataset license can be different. |
| RecoFit | https://github.com/microsoft/Exercise-Recognition-from-Wearable-Sensors | Arm-worn placement differs from Apple Watch; audit label mapping and licensing. |

**Never invent exact per-repetition event timestamps from set-level rep totals.** Counts, set boundaries and approximate peaks are different annotation types.

## Required generated files (do not fabricate entries)
1. `ml/exercise_inventory.csv`: `source,raw_label,canonical_label,placement,subject_count,session_count,window_count,annotation_type,license_status,eligible,exclusion_reason`.
2. `ml/label_map.json`: aliases, exclusions, canonical IDs, and ambiguous mappings.
3. `ml/evaluations/<run_id>/`: training configuration, dataset fingerprints, held-out subjects, class counts, confusion matrix, classification report, OOD/unknown false-positive rate, rep-count MAE, power/latency measurements when available.
4. `ml/exercise_support_registry.json`: `exerciseId,status,trainingSources,metricVersion,watchValidationDevice,perClassPrecision,perClassRecall,reason`.
5. `ml/README.md`: repeatable setup/download/ETL/train/evaluate/export steps and licensing notes.

## Support tier rules
- **candidate:** found in eligible data, not yet trained.
- **trained:** model contains that class and offline held-out evaluation exists. Must not be silently auto-logged.
- **watchTested:** direct manually verified Apple Watch observations exist; results and tested device are recorded.
- **autoEnabled:** acceptable per-class precision and rep-count quality measured on Apple Watch, including negative examples and realistic transitions, and a product decision approves the class.
- **manualOnly:** physically unobservable from wrist, ambiguous, poorly performing, or unlicensed; can still be logged by hand.

Define numerical auto-enable thresholds from a small pilot, with false-positive cost weighted heavily. Set-level rep counting must be evaluated separately from exercise classification. Never invent thresholds as measurements; report chosen policy explicitly.

## Training approach
1. Inventory every class before selecting a shortlist; count unique exercises after cautious label harmonization.
2. Build reliable subject-disjoint splits, then train a classical feature baseline.
3. Train compact 1D CNN/TCN on 6-channel motion sequences; compare direct multiclass against hierarchical movement-family + exercise subtype models.
4. Tune unknown rejection on out-of-class and normal wrist activity; do not optimize on held-out test participants.
5. Validate on the physical Apple Watch SE (2nd generation, 2022). If the model is too heavy, reduce compute or use category-specific heads; do not make fictional inference claims.
6. Build a generated support registry read by the app, and show confidence/unknown options in its UI.
7. For severely wrist-still exercises (leg extensions, curls, some presses), choose manual logging in the prototype rather than guess.

## Prototype milestone report
Each demo report must show these **separate** numbers (measured, never pre-filled):
- Dataset labels discovered / eligible canonical classes
- Classes the trained classifier predicts
- Classes tested on a physical Apple Watch SE (2nd generation)
- Classes enabled for automatic logging
- Per-class recognition metrics and per-set rep-count error
- Real Watch runtime/battery evidence, or explicit hardware blockers

## Scope order
First make the manually logged session durable; then demonstrate Watch IMU capture and replay; then train/evaluate the broad class set; finally enable only proven classes for live auto-detection. The three common exercises (curls, shoulder press, squat) are convenient integration tests, not a maximum scope.

## SE 2 validation checklist
- Log exact watchOS version, paired iPhone model and iOS version, Watch size and battery condition, watch wearing wrist, and handedness.
- Record 20–30 minute IMU session and check dropped samples / timestamp gaps; repeat with screen dimmed and normal workout background lifecycle.
- Compare iPhone inference versus on-Watch inference using identical prerecorded windows, recording end-to-end latency, memory, and battery impact.
- Confirm on-device rest-end haptic/sound behavior in the actual Watch configuration; provide visual fallback.
- Exercise labels discovered in public datasets are **experimental** until validated on the SE 2 itself.
