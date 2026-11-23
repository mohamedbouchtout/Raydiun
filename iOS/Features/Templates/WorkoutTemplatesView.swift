import SwiftUI

struct WorkoutTemplatesView: View {
    private let store = WorkoutTemplateStore.local
    @State private var templates: [WorkoutTemplate]?
    @State private var loadFailed = false
    @State private var draft: WorkoutTemplate?
    @State private var pendingDeletion: WorkoutTemplate?
    @State private var saveFailed = false

    var body: some View {
        Group {
            if let templates {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label("No templates", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Create a template to plan your next workout.")
                    } actions: {
                        Button("New Template", action: makeDraft)
                            .accessibilityIdentifier("templates.empty.add")
                    }
                } else {
                    List(templates) { template in
                        Button {
                            draft = template
                        } label: {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                Text(template.goal.rawValue.capitalized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) { pendingDeletion = template }
                        }
                        .accessibilityAction(named: Text("Delete template")) {
                            pendingDeletion = template
                        }
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
        .navigationTitle("Templates")
        .toolbar {
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
            WorkoutTemplateEditor(template: template, onSave: save)
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

    let onSave: (WorkoutTemplate) throws -> Void

    init(template: WorkoutTemplate, onSave: @escaping (WorkoutTemplate) throws -> Void) {
        _template = State(initialValue: template)
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
                            TemplateExerciseEditor(exercise: $exercise)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(StarterExercises.name(for: exercise.exerciseId))
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
            .sheet(isPresented: $choosingExercise) {
                NavigationStack {
                    List(StarterExercises.all) { exercise in
                        Button(exercise.name) {
                            template.exercises.append(TemplateExercise(
                                id: UUID(), exerciseId: exercise.id, targetSets: 3, repMin: 8,
                                repMax: 12, initialRestSeconds: 90,
                                position: template.exercises.count, preferredWeightUnit: .kg
                            ))
                            choosingExercise = false
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
        .navigationTitle(StarterExercises.name(for: exercise.exerciseId))
    }
}

private enum StarterExercises {
    static let all = [
        exercise(1, "Biceps Curl", "Arms"),
        exercise(2, "Shoulder Press", "Shoulders"),
        exercise(3, "Squat", "Legs"),
        exercise(4, "Bench Press", "Chest"),
        exercise(5, "Dumbbell Row", "Back"),
        exercise(6, "Deadlift", "Posterior Chain")
    ]

    static func name(for id: UUID) -> String {
        all.first { $0.id == id }?.name ?? "Unknown Exercise"
    }

    private static func exercise(_ number: UInt8, _ name: String, _ category: String) -> ExerciseDefinition {
        ExerciseDefinition(
            id: UUID(uuid: (0x44, 0x2C, 0x02, 0xEF, 0x83, 0x8C, 0x49, 0x90, 0x91, 0xB4, 0x24, 0x3B, 0x11, 0x5C, 0xA0, number)),
            name: name, movementCategory: category, supportTier: .manualOnly,
            isCustom: false, createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
