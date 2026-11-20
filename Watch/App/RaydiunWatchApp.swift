import SwiftUI

@main
struct RaydiunWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WorkoutPreview()
        }
    }
}

private struct WorkoutPreview: View {
    private enum Screen: Hashable {
        case active, rest, summary
    }

    @State private var path: [Screen] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                EmptyScreen(
                    title: "Workout Preview",
                    icon: "figure.strengthtraining.traditional",
                    detail: "Explore the workout screens. Recording is off."
                )
                NavigationLink("Start preview", value: Screen.active)
                    .accessibilityIdentifier("watch.preview.start")
            }
            .navigationTitle("Raydiun")
            .navigationDestination(for: Screen.self) { screen in
                switch screen {
                case .active:
                    List {
                        EmptyScreen(
                            title: "Preview",
                            icon: "figure.strengthtraining.traditional",
                            detail: "Exercise and rep count will appear here."
                        )
                        NavigationLink("Preview rest", value: Screen.rest)
                            .accessibilityIdentifier("watch.preview.rest")
                    }
                    .navigationTitle("Active Set")
                case .rest:
                    List {
                        EmptyScreen(
                            title: "Preview",
                            icon: "timer",
                            detail: "Remaining rest time will appear here."
                        )
                        NavigationLink("Preview summary", value: Screen.summary)
                            .accessibilityIdentifier("watch.preview.summary")
                    }
                    .navigationTitle("Rest")
                case .summary:
                    List {
                        EmptyScreen(
                            title: "Preview",
                            icon: "list.bullet",
                            detail: "Completed sets will appear here."
                        )
                        Button("Close preview") { path.removeAll() }
                            .accessibilityIdentifier("watch.preview.close")
                    }
                    .navigationTitle("Summary")
                }
            }
        }
    }
}
