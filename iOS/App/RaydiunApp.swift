import SwiftUI
import UIKit

@main
struct RaydiunApp: App {
    @State private var tab = PhoneTab.home
    @State private var showingProfile = false
    @State private var selectedDate = Date()
    @State private var showingCalendar = false
    @State private var workoutRoute: WorkoutRoute?
    @State private var workoutStore = PhoneWorkoutStore()
    @State private var setup = TrainingSetupStore()
    @State private var showingSetup = false
    @State private var walkthroughOffer = false
    @State private var presentingWalkthroughOffer = false
    @State private var setupError = false
    @State private var existingInstall = false
    @State private var showingIntro = true
    @State private var introFading = false
    @Environment(\.calendar) private var calendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if setup.welcomeCompleted || existingInstall || setup.loadFailed {
                        phoneTabs
                    } else {
                        RaydiunWelcome(continuing: setup.hasDraft, build: { showingSetup = true }) {
                            saveSetup { try setup.completeWelcome() }
                        }
                    }
                }
                .accessibilityHidden(showingIntro)
                .allowsHitTesting(!showingIntro)
                if showingIntro {
                    launchIntro
                        .zIndex(1)
                }
            }
            .tint(PhonePalette.action)
            .task {
                let hasLocalData = workoutStore.loadError != nil || !workoutStore.sessions.isEmpty || hasSavedTemplates()
                existingInstall = hasLocalData && !setup.hasDraft
                if existingInstall && !setup.welcomeCompleted && !setup.loadFailed {
                    saveSetup { try setup.completeWelcome() }
                }
                #if DEBUG && targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains("-RaydiunSkipWelcome") {
                    existingInstall = true
                    showingIntro = false
                    return
                }
                #endif
                await playIntro()
            }
            .sheet(isPresented: $showingSetup, onDismiss: offerWalkthroughIfNeeded) {
                TrainingSetupView(store: setup) {
                    tab = .home
                    selectedDate = .now
                    walkthroughOffer = setup.walkthrough == .inactive && workoutStore.completed.isEmpty
                }
            }
            .alert("First workout", isPresented: $presentingWalkthroughOffer) {
                Button("Show me") { startWalkthrough() }
                Button("Maybe later", role: .cancel) {}
            } message: {
                Text("Follow a short walkthrough to log your first workout and find it in Training Log.")
            }
            .alert("Couldn’t save setup changes", isPresented: $setupError) {
                Button("OK", role: .cancel) {}
            }
            .onChange(of: workoutStore.active?.id, initial: true) { _, _ in observeWorkout() }
            .onChange(of: workoutStore.active?.confirmedSets.count) { _, _ in observeWorkout() }
            .onChange(of: workoutStore.completed.first?.id) { _, _ in observeWorkout() }
        }
    }

    private var phoneTabs: some View {
        TabView(selection: $tab) {
            destination(.home) {
                TodayView(selectedDate: $selectedDate, isVisible: tab == .home, store: workoutStore, setup: setup,
                          dismissWalkthrough: { saveSetup { try setup.dismissWalkthrough() } },
                          openTrainingSetup: openTrainingSetup, openWorkout: openWorkout,
                          openProfile: { showingProfile = true })
                    .navigationDestination(isPresented: $showingProfile) { profile }
            }
            destination(.train) {
                WorkoutTemplatesView(setup: setup) { day in
                    selectedDate = day
                    tab = .home
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Calendar", systemImage: "calendar") { showingCalendar = true }
                    }
                }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                    Button(workoutStore.active == nil ? "Start Workout" : "Resume Workout") { openWorkout(nil) }
                        .buttonStyle(RaydiunPrimaryButton())
                        .accessibilityIdentifier("train.workout")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(PhonePalette.canvas)
                }
            }
            destination(.coach) {
                CoachView(store: workoutStore) { tab = .progress }
            }
            destination(.log) {
                PhoneWorkoutLogView(store: workoutStore)
            }
            destination(.progress) {
                PhoneWorkoutProgressView(store: workoutStore)
            }
        }
        .background(PhonePalette.canvas.ignoresSafeArea())
        .onChange(of: tab) { _, selected in
            if selected == .log { saveSetup { try setup.viewedLog() } }
        }
        .tint(PhonePalette.action)
        .sheet(item: $workoutRoute) { route in
            PhoneWorkoutView(store: workoutStore, preferredTemplateID: route.templateID, setup: setup) {
                saveSetup { try setup.dismissWalkthrough() }
            }
        }
        .sheet(isPresented: $showingCalendar) {
            NavigationStack {
                Form {
                    DatePicker("Workout date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .listRowBackground(PhonePalette.surface)
                    Button("Go to Today") {
                        selectedDate = .now
                        openSelectedDay()
                    }
                    .listRowBackground(PhonePalette.surface)
                }
                .raydiunScreen()
                .navigationTitle("Calendar")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: openSelectedDay)
                    }
                }
            }
        }
    }

    private var profile: some View {
        List {
            Section("Training") {
                Button(setup.hasSplit ? "Edit weekly split" : "Training setup", systemImage: "calendar",
                       action: openTrainingSetup)
                .accessibilityIdentifier("profile.trainingSetup")
                Button("First workout walkthrough", systemImage: "figure.strengthtraining.traditional") {
                    showingProfile = false
                    startWalkthrough()
                }
                .accessibilityIdentifier("profile.walkthrough")
            }
            .listRowBackground(PhonePalette.surface)
            Section("Privacy") {
                Label("Workout data stays on your devices", systemImage: "lock")
                    .listRowBackground(PhonePalette.surface)
            }
        }
        .raydiunScreen()
        .navigationTitle("Profile")
        .toolbar(.visible, for: .navigationBar)
    }

    private var launchIntro: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.40, blue: 0.34),
                                    Color(red: 0.04, green: 0.14, blue: 0.11)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .opacity(introFading ? 0 : 1)
            CoachMark(size: 110)
                .foregroundStyle(.white)
                .scaleEffect(introFading && !reduceMotion ? 1.46 : 1)
                .opacity(introFading ? 0 : 1)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func playIntro() async {
        guard showingIntro else { return }
        do {
            try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 500))
            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.45)) { introFading = true }
            try await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 450))
        } catch {
            // If the launch view is cancelled, reveal the destination immediately.
        }
        showingIntro = false
    }

    private func hasSavedTemplates() -> Bool {
        do { return try !WorkoutTemplateStore.local.load().isEmpty }
        catch { return true }
    }

    private func openTrainingSetup() {
        saveSetup {
            try setup.editCurrentSplit(now: .now, calendar: calendar)
            showingSetup = true
        }
    }

    private func offerWalkthroughIfNeeded() {
        guard walkthroughOffer else { return }
        walkthroughOffer = false
        presentingWalkthroughOffer = true
    }

    private func startWalkthrough() {
        saveSetup {
            try setup.startWalkthrough()
            observeWorkout()
            tab = .home
        }
    }

    private func observeWorkout() {
        saveSetup { try setup.observeWorkout(active: workoutStore.active, completed: workoutStore.completed) }
    }

    private func saveSetup(_ change: () throws -> Void) {
        do { try change() }
        catch { setupError = true }
    }

    private func destination<Content: View>(_ destination: PhoneTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack { content() }
            .tabItem { destination.icon.accessibilityLabel(destination.label) }
            .tag(destination)
    }

    private func openWorkout(_ templateID: UUID?) {
        workoutRoute = WorkoutRoute(templateID: templateID)
    }

    private func openSelectedDay() {
        showingCalendar = false
        tab = .home
    }
}

private struct WorkoutRoute: Identifiable {
    let id = UUID()
    let templateID: UUID?
}

private enum PhoneTab: Hashable {
    case home, train, coach, log, progress

    var label: String {
        switch self {
        case .home: "Today"
        case .train: "Train"
        case .coach: "Coach"
        case .log: "Log"
        case .progress: "Progress"
        }
    }

    var icon: Image {
        switch self {
        case .home: Image(systemName: "house")
        case .train: Image(systemName: "dumbbell")
        case .coach: Image("CoachMark").renderingMode(.template)
        case .log: Image(systemName: "book.closed")
        case .progress: Image(systemName: "chart.bar")
        }
    }
}

enum PhonePalette {
    static let canvas = adaptive(0xF0F3EF, 0x0D1F19)
    static let glow = adaptive(0xB8DBCC, 0x204638)
    static let surface = adaptive(0xFDFEFD, 0x13251F)
    static let line = adaptive(0xDCE4DE, 0x263B33)
    static let ink = adaptive(0x12231D, 0xFCFFFD)
    static let muted = adaptive(0x52625A, 0xABC6BA)
    static let action = adaptive(0x1D493D, 0x94D6BF)
    static let onAction = adaptive(0xFFFFFF, 0x0D211A)
    static let brandMark = adaptive(0x1D493D, 0xFCFFFD)
    static let quietFill = adaptive(0xE2E9E3, 0x1C2C26)
    static let badge = adaptive(0xE4EFE9, 0x19382F)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

struct RaydiunPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1.6)
            .multilineTextAlignment(.center)
            .foregroundStyle(PhonePalette.onAction)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(PhonePalette.action, in: Capsule())
            .contentShape(Rectangle())
            .accessibilityActivationPoint(.center)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 12, y: 7)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
    }
}

extension View {
    func raydiunCard(radius: CGFloat = 22) -> some View {
        background(PhonePalette.surface, in: RoundedRectangle(cornerRadius: radius))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(PhonePalette.line) }
            .foregroundStyle(PhonePalette.ink)
    }

    func raydiunScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(PhonePalette.canvas.ignoresSafeArea())
            .foregroundStyle(PhonePalette.ink)
            .toolbarBackground(PhonePalette.canvas, for: .navigationBar)
            .tint(PhonePalette.action)
    }
}
