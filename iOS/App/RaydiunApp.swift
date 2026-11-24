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
                .tabItem { Image(systemName: "house").accessibilityLabel("Today") }
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
                    .tabItem { Image(systemName: "dumbbell").accessibilityLabel("Train") }
                    .tag(PhoneTab.train)

                NavigationStack {
                    CoachView(store: workoutStore) { tab = .progress }
                }
                .tabItem { Image("CoachMark").renderingMode(.template).accessibilityLabel("Coach") }
                .tag(PhoneTab.coach)

                NavigationStack {
                    PhoneWorkoutLogView(store: workoutStore)
                }
                .tabItem { Image(systemName: "book.closed").accessibilityLabel("Log") }
                .tag(PhoneTab.log)

                NavigationStack {
                    PhoneWorkoutProgressView(store: workoutStore)
                }
                .tabItem { Image(systemName: "chart.bar").accessibilityLabel("Progress") }
                .tag(PhoneTab.progress)
            }
            .tint(.accentColor)
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
    case today, train, coach, log, progress
}
