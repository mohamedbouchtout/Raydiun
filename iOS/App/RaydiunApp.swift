import SwiftUI

@main
struct RaydiunApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    EmptyScreen(
                        title: "No active workout",
                        icon: "figure.strengthtraining.traditional",
                        detail: "Your active workout will appear here."
                    )
                    .navigationTitle("Today")
                }
                .tabItem { Label("Today", systemImage: "calendar") }

                NavigationStack {
                    WorkoutTemplatesView()
                }
                .tabItem { Label("Templates", systemImage: "list.bullet.clipboard") }

                NavigationStack {
                    EmptyScreen(
                        title: "No workout history",
                        icon: "clock",
                        detail: "Completed workouts will appear here."
                    )
                    .navigationTitle("History")
                }
                .tabItem { Label("History", systemImage: "clock") }

                NavigationStack {
                    EmptyScreen(
                        title: "No progress data",
                        icon: "chart.line.uptrend.xyaxis",
                        detail: "Log workouts to see your progress over time."
                    )
                    .navigationTitle("Progress")
                }
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

                NavigationStack {
                    List {
                        Section("Privacy") {
                            Label("Workout data stays on your devices", systemImage: "lock")
                        }
                    }
                    .navigationTitle("Settings")
                }
                .tabItem { Label("Settings", systemImage: "gearshape") }
            }
        }
    }
}
