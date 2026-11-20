# Raydiun — Codex + Xcode Prototype Project Brief

**Confirmed test watch: Apple Watch SE (2nd generation, 2022).** This device supports the motion-sensing prototype; plan and benchmark against the actual watch rather than presuming a Series 6 or Series 8 is available.

Raydiun is an offline-first iPhone and Apple Watch strength-workout prototype. The Phase 0 project contains the app shells, shared domain models, and starter navigation.

## Confirmed project requirements
- App name: **Raydiun** (use in Xcode target names and displayed UI).
- Device target: Apple Watch **SE (2nd generation, 2022)** with a compatible paired iPhone; benchmark on the actual SE 2.
- Goal: executable **prototype**, not an App Store or TestFlight submission.
- Recognition: audit and model **as many distinct exercises as available permissible datasets justify**, not just three. Train broadly; enable automatic logging per validated class only.

## Documents
- `AGENTS.md`: coding-agent rules, engineering guardrails, platform boundaries, definition of done.
- [PRODUCT.md](docs/PRODUCT.md): V1 features, what will and won't ship, user journeys, acceptance metrics.
- [ARCHITECTURE.md](docs/ARCHITECTURE.md): app layers, watch-to-phone sync, sensor pipeline, schemas, ML and evaluation details.
- [TASKS.md](TASKS.md): ordered, testable P0 and P1 checklists plus ready-to-paste Codex prompts.
- [DECISIONS.md](docs/DECISIONS.md): confirmed user choices, remaining hardware/bundle-ID unknowns, architecture log.
- [ML_COVERAGE.md](docs/ML_COVERAGE.md): detailed dataset taxonomy, model validation gates, and experiment deliverables.

## Build and run

Open `Raydiun.xcodeproj` in Xcode. Select **Raydiun** and an iPhone simulator, or **RaydiunWatch** and an Apple Watch simulator, then press Run. If the destination list is empty, install the corresponding iOS or watchOS simulator runtime in Xcode Settings and create a simulator in Devices and Simulators.

The minimums are iOS 17 and watchOS 10. For physical deployment, select your signing team and replace the temporary bundle IDs in both targets. Keep the Watch bundle ID prefixed with the iPhone bundle ID and update the Watch target's companion bundle ID to match.

```sh
swift test
xcodebuild -project Raydiun.xcodeproj -scheme Raydiun -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/iOS CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -project Raydiun.xcodeproj -scheme RaydiunWatch -destination 'generic/platform=watchOS Simulator' -derivedDataPath DerivedData/Watch CODE_SIGNING_ALLOWED=NO build
```

To run the iPhone navigation test, select an installed iPhone simulator and choose Product → Test in the **Raydiun** scheme. On Watch, follow **Start preview → Preview rest → Preview summary → Close preview**. See [TASKS.md](TASKS.md) for verification status.

## Documentation sources
- Core Motion: https://developer.apple.com/documentation/coremotion/cmmotionmanager
- HealthKit workouts: https://developer.apple.com/documentation/healthkit/hkworkoutsession
- WatchConnectivity: https://developer.apple.com/documentation/watchconnectivity
- Core ML Tools: https://apple.github.io/coremltools/docs-guides/source/convert-pytorch-workflow.html
- Codex CLI: https://developers.openai.com/codex/cli
- MM-Fit: https://mmfit.github.io/
- RecoFit: https://github.com/microsoft/Exercise-Recognition-from-Wearable-Sensors
