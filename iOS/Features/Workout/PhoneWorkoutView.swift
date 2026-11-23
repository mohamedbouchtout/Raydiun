import SwiftUI

struct PhoneWorkoutView: View {
    let store: PhoneWorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var library = ExerciseLibrary()
    @State private var templates: [WorkoutTemplate] = []
    @State private var templateError: String?
    @State private var errorMessage: String?
    @State private var choosingExercise = false
    @State private var editingSet: SetRecord?
    @State private var selectedExercise: UUID?
    @State private var reps = ""
    @State private var weight = ""
    @State private var unit: WeightUnit = .kg
    @State private var restSeconds = 90

    var body: some View {
        NavigationStack {
            Group {
                if let error = store.loadError {
                    ContentUnavailableView("Workout data unavailable", systemImage: "exclamationmark.triangle",
                                           description: Text(error + " No changes can be saved."))
                } else if let workout = store.active {
                    activeContent(workout)
                } else {
                    startContent
                }
            }
            .navigationTitle(store.active?.title ?? "Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task {
                library.loadIfNeeded()
                reloadTemplates()
            }
            .sheet(isPresented: $choosingExercise) {
                NavigationStack {
                    Group {
                        if let exercises = library.exercises {
                            List(exercises) { exercise in
                                Button(exercise.name) {
                                    perform { try store.addExercise(exercise) }
                                    choosingExercise = false
                                }
                            }
                        } else {
                            ContentUnavailableView("Exercise library unavailable", systemImage: "exclamationmark.triangle")
                        }
                    }
                    .navigationTitle("Add Exercise")
                    .toolbar { Button("Cancel") { choosingExercise = false } }
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedExercise != nil || editingSet != nil },
                set: { if !$0 { selectedExercise = nil; editingSet = nil } }
            )) {
                NavigationStack {
                    Form {
                        TextField("Reps", text: $reps).keyboardType(.numberPad)
                        TextField("Weight (optional)", text: $weight).keyboardType(.decimalPad)
                        Picker("Unit", selection: $unit) {
                            Text("kg").tag(WeightUnit.kg)
                            Text("lb").tag(WeightUnit.lb)
                        }
                    }
                    .navigationTitle(editingSet == nil ? "Log Set" : "Edit Set")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { selectedExercise = nil; editingSet = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save", action: saveSet).disabled(Int(reps) == nil)
                        }
                    }
                }
            }
            .alert("Workout not saved", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Try again.")
            }
        }
    }

    private var startContent: some View {
        List {
            Section("Manual training") {
                Button("Start Blank Workout", systemImage: "plus") {
                    perform { try store.start(template: nil, library: library) }
                }
            }
            Section("From a saved template") {
                if let templateError {
                    Text(templateError).foregroundStyle(.secondary)
                    Button("Retry", action: reloadTemplates)
                } else if templates.isEmpty {
                    Text("No saved templates. Start blank or create one in Train.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { template in
                        Button(template.name) {
                            perform { try store.start(template: template, library: library) }
                        }
                    }
                }
            }
            Section {
                Text("Manual iPhone logging only. Motion recognition and Watch tracking are unavailable.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func activeContent(_ workout: PhoneWorkoutSummary) -> some View {
        List {
            Section {
                LabeledContent("Started", value: workout.session.startedAt.formatted(date: .abbreviated, time: .shortened))
                Text(workout.session.status == .paused ? "Paused" : "In progress")
                if let end = workout.restEnd {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(end.timeIntervalSince(context.date).rounded(.up)))
                        Text(remaining == 0 ? "Rest complete" : "Rest: \(remaining)s remaining")
                            .monospacedDigit()
                    }
                }
                if workout.session.status == .paused {
                    Button("Resume", systemImage: "play.fill") { perform { try store.resume() } }
                } else {
                    Button("Pause", systemImage: "pause.fill") { perform { try store.pause() } }
                    Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 5...3600, step: 5)
                    Button("Start Rest", systemImage: "timer") { perform { try store.rest(seconds: restSeconds) } }
                }
            }
            ForEach(workout.exercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sets) { set in
                        HStack {
                            Text("Set \(set.index): \(set.reps) reps")
                            Spacer()
                            if let weight = set.weight {
                                Text("\(weight.value(in: weight.displayUnit), specifier: "%.1f") \(weight.displayUnit.rawValue)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(allowsFullSwipe: false) {
                            Button("Undo", role: .destructive) { perform { try store.undoSet(set.id) } }
                            Button("Edit") { openEditor(for: set) }
                        }
                    }
                    if workout.session.status != .paused {
                        Button("Log Set", systemImage: "plus") { openEditor(for: exercise.id) }
                    }
                }
            }
            Section {
                Button("Add Exercise", systemImage: "plus") { choosingExercise = true }
                    .disabled(workout.session.status == .paused)
                Button("Finish Workout", systemImage: "checkmark") {
                    perform { try store.finish() }
                }
            }
        }
    }

    private func openEditor(for performanceId: UUID) {
        editingSet = nil
        reps = ""
        weight = ""
        unit = .kg
        selectedExercise = performanceId
    }

    private func openEditor(for set: SetRecord) {
        selectedExercise = nil
        editingSet = set
        reps = String(set.reps)
        unit = set.weight?.displayUnit ?? .kg
        weight = set.weight.map { String($0.value(in: unit)) } ?? ""
    }

    private func saveSet() {
        guard let count = Int(reps), count > 0, count <= 999 else {
            errorMessage = "Reps must be between 1 and 999."
            return
        }
        let trimmed = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        var amount: WorkoutWeight?
        if !trimmed.isEmpty {
            guard let value = Double(trimmed), let valid = WorkoutWeight(value: value, unit: unit) else {
                errorMessage = "Enter a nonnegative, finite weight."
                return
            }
            amount = valid
        }
        do {
            if let editingSet {
                try store.editSet(editingSet.id, reps: count, weight: amount)
            } else if let selectedExercise {
                try store.recordSet(performanceId: selectedExercise, reps: count, weight: amount)
            }
            editingSet = nil
            selectedExercise = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadTemplates() {
        do {
            templates = try WorkoutTemplateStore.local.load()
            templateError = nil
        } catch {
            templateError = "Saved templates could not be read. Blank workouts remain available."
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { errorMessage = error.localizedDescription }
    }
}

struct PhoneWorkoutLogView: View {
    let store: PhoneWorkoutStore

    var body: some View {
        Group {
            if store.loadError != nil {
                ContentUnavailableView("Workout history unavailable", systemImage: "exclamationmark.triangle")
            } else if store.completed.isEmpty {
                ContentUnavailableView("No completed workouts", systemImage: "book.closed",
                                       description: Text("Finish a manual workout to see confirmed sets here."))
            } else {
                List(store.completed) { workout in
                    Section {
                        ForEach(workout.exercises) { exercise in
                            if !exercise.sets.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name).font(.headline)
                                    ForEach(exercise.sets.filter(\.confirmed)) { set in
                                        HStack {
                                            Text("\(set.reps) reps")
                                            Spacer()
                                            if let weight = set.weight {
                                                Text("\(weight.value(in: weight.displayUnit), specifier: "%.1f") \(weight.displayUnit.rawValue)")
                                            }
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("\(workout.title) · \(workout.session.endedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                    }
                }
            }
        }
        .navigationTitle("Log")
    }
}

// A workout belongs to the calendar week in which it was finished. Only effective,
// confirmed sets in committed, finished sessions are included in these totals.
private struct PhoneWorkoutWeek: Identifiable {
    let id: Date
    var workouts: Int
    var sets: Int
}

struct PhoneWorkoutProgressView: View {
    let store: PhoneWorkoutStore
    @Environment(\.calendar) private var calendar

    private var weeks: [PhoneWorkoutWeek] {
        var totals: [Date: PhoneWorkoutWeek] = [:]
        for workout in store.completed {
            guard let finished = workout.session.endedAt,
                  !workout.confirmedSets.isEmpty,
                  let weekStart = calendar.dateInterval(of: .weekOfYear, for: finished)?.start
            else { continue }
            var week = totals[weekStart] ?? PhoneWorkoutWeek(id: weekStart, workouts: 0, sets: 0)
            week.workouts += 1
            week.sets += workout.confirmedSets.count
            totals[weekStart] = week
        }
        return totals.values.sorted { $0.id > $1.id }
    }

    var body: some View {
        Group {
            if let error = store.loadError {
                ContentUnavailableView("Progress unavailable", systemImage: "exclamationmark.triangle",
                                       description: Text(error + " Workout data could not be read."))
            } else if weeks.isEmpty {
                ContentUnavailableView("No progress data", systemImage: "chart.bar",
                                       description: Text("Finish a workout with confirmed sets to see weekly totals."))
            } else {
                List(weeks) { week in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Week of \(week.id.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.headline)
                        Text("\(week.workouts) \(week.workouts == 1 ? "workout" : "workouts") · \(week.sets) confirmed \(week.sets == 1 ? "set" : "sets")")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Progress")
    }
}
