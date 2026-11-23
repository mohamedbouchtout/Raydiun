import SwiftUI

struct ExerciseCatalogContent<Content: View>: View {
    let library: ExerciseLibrary
    @ViewBuilder let content: ([ExerciseDefinition]) -> Content

    var body: some View {
        Group {
            if let exercises = library.exercises {
                content(exercises)
            } else if library.loadFailed {
                ContentUnavailableView {
                    Label("Exercise library couldn’t load", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("Try Again", action: library.load)
                }
            } else {
                ProgressView("Loading exercises")
            }
        }
        .task { library.loadIfNeeded() }
    }
}

struct ExerciseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let library: ExerciseLibrary

    var body: some View {
        ExerciseCatalogContent(library: library) { exercises in
            List {
                Section("Custom Exercises") {
                    ForEach(exercises.filter(\.isCustom)) { exercise in
                        NavigationLink {
                            CustomExerciseEditor(library: library, exercise: exercise)
                        } label: {
                            exerciseLabel(exercise)
                        }
                    }
                    if !exercises.contains(where: \.isCustom) {
                        Text("No custom exercises").foregroundStyle(.secondary)
                    }
                }
                Section("Built-In Exercises") {
                    ForEach(exercises.filter { !$0.isCustom }) { exercise in
                        exerciseLabel(exercise)
                    }
                }
            }
        }
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            if library.exercises != nil {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        CustomExerciseEditor(library: library)
                    } label: {
                        Label("Add Custom Exercise", systemImage: "plus")
                    }
                    .accessibilityIdentifier("exercise.library.add")
                }
            }
        }
    }

    private func exerciseLabel(_ exercise: ExerciseDefinition) -> some View {
        VStack(alignment: .leading) {
            Text(exercise.name)
            Text(exercise.movementCategory.isEmpty ? "Manual only" : "\(exercise.movementCategory) · Manual only")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CustomExerciseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: String
    @State private var validationMessage: String?
    @State private var saveFailed = false

    let library: ExerciseLibrary
    let exerciseID: UUID?

    init(library: ExerciseLibrary, exercise: ExerciseDefinition? = nil) {
        self.library = library
        exerciseID = exercise?.id
        _name = State(initialValue: exercise?.name ?? "")
        _category = State(initialValue: exercise?.movementCategory ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField("Exercise name", text: $name)
                    .accessibilityIdentifier("exercise.custom.name")
                TextField("Movement category (optional)", text: $category)
                    .accessibilityIdentifier("exercise.custom.category")
            } footer: {
                if let validationMessage {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("exercise.custom.validation")
                } else {
                    Text("Custom exercises are available for manual selection.")
                }
            }
        }
        .navigationTitle(exerciseID == nil ? "New Exercise" : "Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: name) { validationMessage = nil }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .accessibilityIdentifier("exercise.custom.save")
            }
        }
        .alert("Couldn’t save exercise", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your edits are still here. Try saving again.")
        }
    }

    private func save() {
        do {
            try library.save(name: name, category: category, editing: exerciseID)
            dismiss()
        } catch let error as ExerciseLibrary.SaveError {
            validationMessage = error.localizedDescription
        } catch {
            saveFailed = true
        }
    }
}
