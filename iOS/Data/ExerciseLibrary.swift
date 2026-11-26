import Foundation
import Observation

private enum StarterExercises {
    static let all = [
        exercise(1, "Biceps Curl", "Arms"),
        exercise(2, "Shoulder Press", "Shoulders"),
        exercise(3, "Squat", "Legs"),
        exercise(4, "Bench Press", "Chest"),
        exercise(5, "Dumbbell Row", "Back"),
        exercise(6, "Deadlift", "Posterior Chain"),
        exercise(7, "Bodyweight Squat", "Legs"),
        exercise(8, "Goblet Squat", "Legs"),
        exercise(9, "Push-Up", "Chest"),
        exercise(10, "Dumbbell Floor Press", "Chest"),
        exercise(11, "Prone Y Raise", "Back"),
        exercise(12, "Glute Bridge", "Posterior Chain"),
        exercise(13, "Dumbbell Romanian Deadlift", "Posterior Chain"),
        exercise(14, "Incline Push-Up", "Chest"),
        exercise(15, "Dumbbell Shoulder Press", "Shoulders"),
        exercise(16, "Reverse Snow Angel", "Back"),
        exercise(17, "Reverse Lunge", "Legs"),
        exercise(18, "Standing Calf Raise", "Legs")
    ]

    private static func exercise(_ number: UInt8, _ name: String, _ category: String) -> ExerciseDefinition {
        ExerciseDefinition(
            id: UUID(uuid: (0x44, 0x2C, 0x02, 0xEF, 0x83, 0x8C, 0x49, 0x90, 0x91, 0xB4, 0x24, 0x3B, 0x11, 0x5C, 0xA0, number)),
            name: name, movementCategory: category, supportTier: .manualOnly,
            isCustom: false, createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}

@MainActor
@Observable
final class ExerciseLibrary {
    enum SaveError: LocalizedError {
        case blankName, duplicateName

        var errorDescription: String? {
            switch self {
            case .blankName: "Enter an exercise name."
            case .duplicateName: "An exercise with this name already exists."
            }
        }
    }

    private let fileURL: URL
    private(set) var exercises: [ExerciseDefinition]?
    private(set) var loadFailed = false

    init(fileURL: URL = RaydiunStorage.directory.appending(path: "custom-exercises-v1.json")) {
        self.fileURL = fileURL
    }

    func name(for id: UUID) -> String {
        exercises?.first { $0.id == id }?.name
            ?? StarterExercises.all.first { $0.id == id }?.name
            ?? "Unknown Exercise"
    }

    func loadIfNeeded() {
        if exercises == nil && !loadFailed { load() }
    }

    func load() {
        do {
            let custom = try loadCustomExercises()
            let customNames = Set(custom.map { Self.nameKey($0.name) })
            let starters = StarterExercises.all.enumerated().filter { index, exercise in
                index < 6 || !customNames.contains(Self.nameKey(exercise.name))
            }.map(\.element)
            let catalog = starters + custom
            guard Set(catalog.map(\.id)).count == catalog.count,
                  Set(catalog.map { Self.nameKey($0.name) }).count == catalog.count,
                  custom.allSatisfy({ $0.isCustom && $0.supportTier == .manualOnly && !Self.nameKey($0.name).isEmpty })
            else { throw CocoaError(.fileReadCorruptFile) }
            exercises = catalog
            loadFailed = false
        } catch {
            exercises = nil
            loadFailed = true
        }
    }

    func save(name: String, category: String, editing id: UUID?) throws {
        guard var updated = exercises else { throw CocoaError(.fileReadUnknown) }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = Self.nameKey(name)
        guard !key.isEmpty else { throw SaveError.blankName }
        guard !updated.contains(where: { $0.id != id && Self.nameKey($0.name) == key })
        else { throw SaveError.duplicateName }

        let category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id {
            guard let index = updated.firstIndex(where: { $0.id == id && $0.isCustom })
            else { throw CocoaError(.fileWriteUnknown) }
            updated[index].name = name
            updated[index].movementCategory = category
        } else {
            updated.append(ExerciseDefinition(
                id: UUID(), name: name, movementCategory: category,
                supportTier: .manualOnly, isCustom: true, createdAt: Date()
            ))
        }

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(updated.filter(\.isCustom)).write(to: fileURL, options: .atomic)
        exercises = updated
    }

    private func loadCustomExercises() throws -> [ExerciseDefinition] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ExerciseDefinition].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
    }

    private static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
    }
}
