import SwiftUI

struct WorkoutTemplatesView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(PhoneSchedule.storageKey) private var scheduleData = Data()

    let openPlannedDay: (Date) -> Void
    private let store = WorkoutTemplateStore.local
    @State private var library = ExerciseLibrary()
    @State private var showingLibrary = false
    @State private var templates: [WorkoutTemplate]?
    @State private var loadFailed = false
    @State private var draft: WorkoutTemplate?
    @State private var pendingDeletion: WorkoutTemplate?
    @State private var saveFailed = false

    var body: some View {
        Group {
            if let templates {
                List {
                    scheduledWorkouts(templates)

                    Section("Saved routines") {
                        if templates.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("No templates").font(.headline)
                                Text("Create a template to plan your next workout.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button("New Template", systemImage: "plus", action: makeDraft)
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("templates.empty.add")
                            }
                            .padding(.vertical, 8)
                        }

                        ForEach(templates) { template in
                            Button {
                                draft = template
                            } label: {
                                HStack {
                                    Image(systemName: "dumbbell")
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading) {
                                        Text(template.name)
                                            .font(.headline)
                                        Text(template.goal.rawValue.capitalized)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) { pendingDeletion = template }
                            }
                            .accessibilityAction(named: Text("Delete template")) {
                                pendingDeletion = template
                            }
                        }
                    }

                    Section("Build a workout") {
                        Button {
                            showingLibrary = true
                        } label: {
                            Label("Exercise Library", systemImage: "books.vertical")
                        }
                        .accessibilityIdentifier("train.exerciseLibrary")
                    }
                }
            } else if loadFailed {
                ContentUnavailableView {
                    Label("Templates couldn’t load", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("Try Again", action: load)
                }
            } else {
                ProgressView("Loading templates")
            }
        }
        .navigationTitle("Train")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Exercise Library", systemImage: "books.vertical") { showingLibrary = true }
                    .accessibilityIdentifier("exercise.library")
            }
            if templates != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Template", systemImage: "plus", action: makeDraft)
                        .accessibilityIdentifier("templates.add")
                }
            }
        }
        .task {
            if templates == nil && !loadFailed { load() }
        }
        .sheet(item: $draft) { template in
            WorkoutTemplateEditor(template: template, library: library, onSave: save)
        }
        .sheet(isPresented: $showingLibrary) {
            NavigationStack {
                ExerciseLibraryView(library: library)
            }
        }
        .confirmationDialog(
            "Delete template?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { template in
            Button("Delete Template", role: .destructive) {
                guard let templates else { return }
                do {
                    try persist(templates.filter { $0.id != template.id })
                } catch {
                    saveFailed = true
                }
            }
        } message: { template in
            Text("“\(template.name)” will be removed from your templates.")
        }
        .alert("Couldn’t delete template", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your template is still available. Try deleting it again.")
        }
    }

    @ViewBuilder
    private func scheduledWorkouts(_ templates: [WorkoutTemplate]) -> some View {
        let today = Date()
        let week = PhoneSchedule.week(containing: today, calendar: calendar)
        let schedule = PhoneSchedule.decode(scheduleData) ?? [:]
        let planned = week.compactMap { day -> (Date, WorkoutTemplate)? in
            let id = schedule[PhoneSchedule.key(for: day, calendar: calendar)]
            guard let id, let template = templates.first(where: { $0.id == id }) else { return nil }
            return (day, template)
        }

        if let next = planned.first(where: { $0.0 >= calendar.startOfDay(for: today) }) {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next planned workout").font(.caption.weight(.semibold))
                    Text(next.1.name).font(.title2.bold())
                    Text(next.0.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("View Workout", systemImage: "chevron.right") { openPlannedDay(next.0) }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 10)
                .listRowBackground(LinearGradient(
                    colors: PhonePalette.cardColors(for: colorScheme),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            }
        }

        Section("This week") {
            if planned.isEmpty {
                Text("No workouts planned this week")
                    .foregroundStyle(.secondary)
            }

            ForEach(week, id: \.self) { day in
                if let template = planned.first(where: { $0.0 == day })?.1 {
                    Button {
                        openPlannedDay(day)
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(template.name).font(.headline)
                                Text(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    }
                }
            }
        }
    }

    private func load() {
        do {
            templates = try store.load()
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    private func makeDraft() {
        draft = WorkoutTemplate(id: UUID(), name: "", goal: .hypertrophy, exercises: [])
    }

    private func save(_ template: WorkoutTemplate) throws {
        guard var updated = templates else { throw CocoaError(.fileReadUnknown) }
        if let index = updated.firstIndex(where: { $0.id == template.id }) {
            updated[index] = template
        } else {
            updated.append(template)
        }
        try persist(updated)
        draft = nil
    }

    private func persist(_ updated: [WorkoutTemplate]) throws {
        try store.save(updated)
        templates = updated
    }
}

private struct WorkoutTemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var template: WorkoutTemplate
    @State private var choosingExercise = false
    @State private var saveFailed = false

    let library: ExerciseLibrary
    let onSave: (WorkoutTemplate) throws -> Void

    init(template: WorkoutTemplate, library: ExerciseLibrary, onSave: @escaping (WorkoutTemplate) throws -> Void) {
        _template = State(initialValue: template)
        self.library = library
        self.onSave = onSave
    }

    private var trimmedName: String {
        template.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    TextField("Template name", text: $template.name)
                        .accessibilityIdentifier("template.name")
                    Picker("Goal", selection: $template.goal) {
                        Text("Strength").tag(WorkoutGoal.strength)
                        Text("Hypertrophy").tag(WorkoutGoal.hypertrophy)
                        Text("Endurance").tag(WorkoutGoal.endurance)
                    }
                }
                Section {
                    ForEach($template.exercises) { $exercise in
                        NavigationLink {
                            TemplateExerciseEditor(exercise: $exercise, name: library.name(for: exercise.exerciseId))
                        } label: {
                            VStack(alignment: .leading) {
                                Text(library.name(for: exercise.exerciseId))
                                Text("\(exercise.targetSets) sets · \(exercise.repMin)–\(exercise.repMax) reps · \(exercise.initialRestSeconds) s rest")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove { template.exercises.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { template.exercises.remove(atOffsets: $0) }

                    Button("Add Exercise", systemImage: "plus") { choosingExercise = true }
                        .accessibilityIdentifier("template.exercise.add")
                } header: {
                    Text("Exercises")
                } footer: {
                    if template.exercises.isEmpty {
                        Text("Add an exercise to save this template.")
                    }
                }
            }
            .navigationTitle("Workout Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty || template.exercises.isEmpty)
                }
                ToolbarItem(placement: .secondaryAction) {
                    EditButton().disabled(template.exercises.isEmpty)
                }
            }
            .task { library.loadIfNeeded() }
            .sheet(isPresented: $choosingExercise) {
                NavigationStack {
                    ExerciseCatalogContent(library: library) { exercises in
                        List(exercises) { exercise in
                            Button(exercise.name) {
                                template.exercises.append(TemplateExercise(
                                    id: UUID(), exerciseId: exercise.id, targetSets: 3, repMin: 8,
                                    repMax: 12, initialRestSeconds: 90,
                                    position: template.exercises.count, preferredWeightUnit: .kg
                                ))
                                choosingExercise = false
                            }
                        }
                    }
                    .navigationTitle("Choose Exercise")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { choosingExercise = false }
                        }
                    }
                }
            }
            .alert("Couldn’t save template", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your edits are still here. Try saving again.")
            }
        }
    }

    private func save() {
        var updated = template
        updated.name = trimmedName
        for index in updated.exercises.indices {
            updated.exercises[index].position = index
        }
        do {
            try onSave(updated)
        } catch {
            saveFailed = true
        }
    }
}

private struct TemplateExerciseEditor: View {
    @Binding var exercise: TemplateExercise
    let name: String

    var body: some View {
        Form {
            Stepper("Target sets: \(exercise.targetSets)", value: $exercise.targetSets, in: 1...99)
                .accessibilityIdentifier("exercise.sets")
            Stepper("Minimum reps: \(exercise.repMin)", value: $exercise.repMin, in: 1...exercise.repMax)
                .accessibilityIdentifier("exercise.reps.minimum")
            Stepper("Maximum reps: \(exercise.repMax)", value: $exercise.repMax, in: exercise.repMin...999)
                .accessibilityIdentifier("exercise.reps.maximum")
            Stepper("Rest: \(exercise.initialRestSeconds) seconds", value: $exercise.initialRestSeconds, in: 0...3600, step: 5)
                .accessibilityIdentifier("exercise.rest")
        }
        .navigationTitle(name)
    }
}
