import SwiftUI
import UIKit

@main
struct RaydiunApp: App {
    @State private var tab = PhoneTab.today
    @State private var showingSettings = false
    @State private var selectedDate = Date()
    @State private var showingWorkout = false
    @State private var workoutStore = PhoneWorkoutStore()

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                NavigationStack {
                    TodayView(
                        selectedDate: $selectedDate,
                        openTrain: { tab = .train },
                        openLog: { tab = .log },
                        openSettings: { showingSettings = true }
                    )
                }
                .tabItem { Label("Today", systemImage: "house") }
                .tag(PhoneTab.today)

                NavigationStack {
                    WorkoutTemplatesView { day in
                        selectedDate = day
                        tab = .today
                    }
                    .safeAreaInset(edge: .bottom) {
                        Button(workoutStore.active == nil ? "Start Workout" : "Resume Workout",
                               systemImage: "figure.strengthtraining.traditional") {
                            showingWorkout = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                    }
                }
                    .tabItem { Label("Train", systemImage: "dumbbell") }
                    .tag(PhoneTab.train)

                NavigationStack {
                    PhoneWorkoutLogView(store: workoutStore)
                }
                .tabItem { Label("Log", systemImage: "book.closed") }
                .tag(PhoneTab.log)

                NavigationStack {
                    PhoneWorkoutProgressView(store: workoutStore)
                }
                .tabItem { Label("Progress", systemImage: "chart.bar") }
                .tag(PhoneTab.progress)
            }
            .tint(Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? .systemMint :
                    UIColor(red: 0.07, green: 0.23, blue: 0.20, alpha: 1)
            }))
            .sheet(isPresented: $showingWorkout) {
                PhoneWorkoutView(store: workoutStore)
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    List {
                        Section("Privacy") {
                            Label("Workout data stays on your devices", systemImage: "lock")
                        }
                    }
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
                }
            }
        }
    }
}

private enum PhoneTab: Hashable {
    case today, train, log, progress
}
