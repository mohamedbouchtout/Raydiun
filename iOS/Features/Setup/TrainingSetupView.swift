import SwiftUI

struct RaydiunWelcome: View {
    let continuing: Bool
    let build: () -> Void
    let skip: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CoachMark(size: 62).foregroundStyle(PhonePalette.brandMark)
                Text("Welcome to Raydiun")
                    .font(.system(.largeTitle, design: .serif))
                    .accessibilityAddTraits(.isHeader)
                Text("Build a strength routine around your goals and the days you can train.")
                    .foregroundStyle(PhonePalette.muted)
                Button(continuing ? "Continue setup" : "Build my plan", action: build)
                    .buttonStyle(RaydiunPrimaryButton())
                    .accessibilityIdentifier("welcome.build")
                Button("Skip for now", action: skip)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("welcome.skip")
            }
            .frame(maxWidth: 440, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .safeAreaPadding(.top, 40)
        .raydiunScreen()
    }
}

struct TrainingSetupView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @State private var library = ExerciseLibrary()
    @State private var answers: TrainingAnswers
    @State private var editing: SplitDay?
    @State private var error: String?

    let store: TrainingSetupStore
    let didSave: () -> Void

    init(store: TrainingSetupStore, didSave: @escaping () -> Void) {
        self.store = store
        self.didSave = didSave
        _answers = State(initialValue: store.answers)
    }

    private var weekdays: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.draft.isEmpty { questionnaire } else { preview }
            }
            .raydiunScreen()
            .navigationTitle(store.draft.isEmpty ? "Training setup" : "Your weekly split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { library.loadIfNeeded() }
        .onChange(of: answers) { _, value in persist { try store.saveDraft(answers: value, days: []) } }
        .sheet(item: $editing) { day in
            WorkoutTemplateEditor(template: day.template, library: library) { updated in
                let days = store.draft.map { item in
                    item.id == updated.id ? SplitDay(weekday: item.weekday, template: updated) : item
                }
                try store.saveDraft(answers: answers, days: days)
                editing = nil
            }
        }
        .alert("Training setup", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private var questionnaire: some View {
        Group {
            Section("Long-term goal") {
                Picker("Primary goal", selection: $answers.goal) {
                    Text("Build strength").tag(WorkoutGoal.strength)
                    Text("Build muscle").tag(WorkoutGoal.hypertrophy)
                    Text("Build endurance").tag(WorkoutGoal.endurance)
                }
                Picker("Time horizon", selection: $answers.horizon) {
                    Text("8 weeks").tag(8)
                    Text("12 weeks").tag(12)
                    Text("24 weeks").tag(24)
                }
                Picker("Experience", selection: $answers.experience) {
                    ForEach(TrainingExperience.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            .listRowBackground(PhonePalette.surface)
            Section("Weekly commitment") {
                ForEach(weekdays, id: \.self) { day in
                    Toggle(calendar.weekdaySymbols[day - 1], isOn: Binding(
                        get: { answers.weekdays.contains(day) },
                        set: { selected in
                            if selected { answers.weekdays.insert(day) } else { answers.weekdays.remove(day) }
                        }
                    ))
                }
                Picker("Time per session", selection: $answers.minutes) {
                    ForEach([20, 30, 45, 60], id: \.self) { Text("\($0) minutes").tag($0) }
                }
                Picker("Equipment", selection: $answers.equipment) {
                    ForEach(TrainingEquipment.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            .listRowBackground(PhonePalette.surface)
            Section {
                Button("Preview my split", action: generate)
                    .disabled(answers.weekdays.isEmpty)
                    .accessibilityIdentifier("setup.preview")
            }
            .listRowBackground(PhonePalette.surface)
        }
    }

    private var preview: some View {
        Group {
            Section {
                Text("\(store.draft.count) sessions per week · \(answers.horizon)-week goal")
                Text("Review the days and routines before saving. Change any workout to make it your own.")
                    .foregroundStyle(PhonePalette.muted)
            }
            .listRowBackground(PhonePalette.surface)
            ForEach(store.draft.sorted { weekdayPosition($0.weekday) < weekdayPosition($1.weekday) }) { day in
                Section {
                    Picker("Training day", selection: Binding(get: { day.weekday }, set: { value in
                        var days = store.draft
                        if let index = days.firstIndex(where: { $0.id == day.id }) {
                            if let occupied = days.firstIndex(where: { $0.weekday == value && $0.id != day.id }) {
                                days[occupied].weekday = day.weekday
                            }
                            days[index].weekday = value
                            persist { try store.saveDraft(answers: answers, days: days) }
                        }
                    })) {
                        ForEach(weekdays, id: \.self) { Text(calendar.weekdaySymbols[$0 - 1]).tag($0) }
                    }
                    Button("Edit \(day.template.name)") { editing = day }
                        .accessibilityIdentifier("setup.editRoutine")
                    if store.draft.count > 1 {
                        Button("Remove this training day", role: .destructive) {
                            persist { try store.saveDraft(answers: answers, days: store.draft.filter { $0.id != day.id }) }
                        }
                    }
                    Text(day.template.exercises.map { library.name(for: $0.exerciseId) }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(PhonePalette.muted)
                }
                .listRowBackground(PhonePalette.surface)
            }
            Section {
                Button("Save weekly split") {
                    persist {
                        try store.activate(now: .now, calendar: calendar)
                        didSave()
                        dismiss()
                    }
                }
                .accessibilityIdentifier("setup.save")
                Button("Change setup answers") {
                    var revised = answers
                    revised.weekdays = Set(store.draft.map(\.weekday))
                    persist {
                        try store.saveDraft(answers: revised, days: [])
                        answers = revised
                    }
                }
            }
            .listRowBackground(PhonePalette.surface)
        }
    }

    private func weekdayPosition(_ weekday: Int) -> Int { weekdays.firstIndex(of: weekday) ?? 0 }

    private func generate() {
        library.load()
        guard let exercises = library.exercises else {
            error = "The exercise library couldn’t load. Try again."
            return
        }
        let split = SplitGenerator.generate(answers, firstWeekday: calendar.firstWeekday, exercises: exercises)
        guard !split.isEmpty else {
            error = "Choose at least one training day."
            return
        }
        persist { try store.saveDraft(answers: answers, days: split) }
    }

    private func persist(_ action: () throws -> Void) {
        do { try action() }
        catch { self.error = "Your changes couldn’t be saved. Try again." }
    }
}

struct FirstWorkoutGuide: View {
    let step: WalkthroughStep
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("First workout").font(.headline).accessibilityAddTraits(.isHeader)
            Text(step.instruction).font(.subheadline).foregroundStyle(PhonePalette.muted)
            Button("Dismiss walkthrough", action: onDismiss)
                .font(.subheadline)
                .frame(minHeight: 44)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .raydiunCard()
        .accessibilityIdentifier("walkthrough.guide")
    }
}
