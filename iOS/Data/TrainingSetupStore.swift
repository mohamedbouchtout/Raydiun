import Foundation
import Observation

enum TrainingExperience: String, Codable, CaseIterable {
    case new, experienced
    var label: String { self == .new ? "New to strength training" : "Training regularly" }
}

enum TrainingEquipment: String, Codable, CaseIterable {
    case bodyweight, dumbbells, gym
    var label: String {
        switch self {
        case .bodyweight: "Bodyweight only"
        case .dumbbells: "Dumbbells"
        case .gym: "Full gym"
        }
    }
}

struct TrainingAnswers: Codable, Equatable {
    var goal: WorkoutGoal = .hypertrophy
    var horizon = 12
    var experience: TrainingExperience = .new
    var weekdays: Set<Int> = [2, 4, 6]
    var minutes = 45
    var equipment: TrainingEquipment = .gym
}

struct SplitDay: Codable, Identifiable {
    var weekday: Int
    var template: WorkoutTemplate
    var id: UUID { template.id }
}

enum SplitGenerator {
    static func generate(_ answers: TrainingAnswers, firstWeekday: Int, exercises: [ExerciseDefinition]) -> [SplitDay] {
        let days = answers.weekdays.sorted { ($0 - firstWeekday + 7) % 7 < ($1 - firstWeekday + 7) % 7 }
        let routines: [Routine]
        switch days.count {
        case 1: routines = [.fullA]
        case 2: routines = [.fullA, .fullB]
        case 3: routines = [.fullA, .fullB, .fullA]
        case 4: routines = [.upper, .lower, .upper, .lower]
        case 5: routines = [.push, .pull, .lower, .upper, .lower]
        case 6...: routines = [.push, .pull, .lower, .push, .pull, .lower]
        default: return []
        }
        let settings: (reps: ClosedRange<Int>, rest: Int)
        switch answers.goal {
        case .strength: settings = (5...8, 180)
        case .hypertrophy: settings = (8...12, 120)
        case .endurance: settings = (12...18, 60)
        }
        let exerciseLimit = answers.minutes <= 30 ? 2 : answers.minutes <= 45 ? 3 : 4
        let sets = answers.experience == .new || answers.minutes <= 30 ? 2 : 3
        return zip(days, routines).compactMap { day, routine in
            let entries = routine.exercises(for: answers.equipment).prefix(exerciseLimit).compactMap { name in
                exercises.first { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }
            }.enumerated().map { index, exercise in
                let reps = answers.equipment == .bodyweight && answers.goal == .strength ? 6...10 : settings.reps
                return TemplateExercise(id: UUID(), exerciseId: exercise.id, targetSets: sets,
                                        repMin: reps.lowerBound, repMax: reps.upperBound,
                                        initialRestSeconds: settings.rest, position: index, preferredWeightUnit: .kg)
            }
            guard !entries.isEmpty else { return nil }
            return SplitDay(weekday: day, template: WorkoutTemplate(id: UUID(), name: routine.rawValue,
                                                                    goal: answers.goal, exercises: entries))
        }
    }

    private enum Routine: String {
        case fullA = "Full body A", fullB = "Full body B"
        case upper = "Upper body", lower = "Lower body", push = "Push", pull = "Pull"

        func exercises(for equipment: TrainingEquipment) -> [String] {
            let squat = equipment == .bodyweight ? "Bodyweight Squat" : equipment == .dumbbells ? "Goblet Squat" : "Squat"
            let press = equipment == .bodyweight ? "Push-Up" : equipment == .dumbbells ? "Dumbbell Floor Press" : "Bench Press"
            let row = equipment == .bodyweight ? "Prone Y Raise" : "Dumbbell Row"
            let hinge = equipment == .bodyweight ? "Glute Bridge" : equipment == .dumbbells ? "Dumbbell Romanian Deadlift" : "Deadlift"
            let shoulder = equipment == .bodyweight ? "Incline Push-Up" : "Dumbbell Shoulder Press"
            let arm = equipment == .bodyweight ? "Reverse Snow Angel" : "Biceps Curl"
            switch self {
            case .fullA: return [squat, press, row, hinge]
            case .fullB: return [hinge, row, shoulder, "Reverse Lunge"]
            case .upper: return [press, row, shoulder, arm]
            case .lower: return [squat, hinge, "Reverse Lunge", "Standing Calf Raise"]
            case .push: return [press, shoulder, "Incline Push-Up"]
            case .pull: return [row, arm, "Prone Y Raise"]
            }
        }
    }
}

enum WalkthroughStep: String, Codable, Equatable {
    case inactive, start, logSet, finish, viewLog, done

    var instruction: String {
        switch self {
        case .inactive, .done: ""
        case .start: "Start a workout when you’re ready. You can choose a routine or start blank."
        case .logSet: "Choose an exercise, then log a set with the reps you completed."
        case .finish: "When you’re done, finish the workout to save it to Training Log."
        case .viewLog: "Tap Log to find your saved workout."
        }
    }
}

private struct RecurringSplit: Codable {
    let effectiveDay: Int
    let routines: [Int: UUID]
}

private struct TrainingSetupRecord: Codable {
    var welcomeCompleted = false
    var answers = TrainingAnswers()
    var draft: [SplitDay] = []
    var splits: [RecurringSplit] = []
    var skippedDates: Set<String> = []
    var walkthrough: WalkthroughStep = .inactive
    var walkthroughWorkoutID: UUID?
}

@MainActor
@Observable
final class TrainingSetupStore {
    private let url: URL
    private var record = TrainingSetupRecord()
    private(set) var loadFailed = false
    private(set) var revision = 0

    init(url: URL = RaydiunStorage.directory.appending(path: "training-setup-v1.json")) {
        self.url = url
        do {
            record = try JSONDecoder().decode(TrainingSetupRecord.self, from: Data(contentsOf: url))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
        } catch {
            loadFailed = true
        }
    }

    var welcomeCompleted: Bool { record.welcomeCompleted }
    var answers: TrainingAnswers { record.answers }
    var draft: [SplitDay] { record.draft }
    var hasDraft: Bool { !record.draft.isEmpty || record.answers != TrainingAnswers() }
    var walkthrough: WalkthroughStep { record.walkthrough }
    var hasSplit: Bool { !record.splits.isEmpty }

    func completeWelcome() throws { try update { $0.welcomeCompleted = true } }

    func saveDraft(answers: TrainingAnswers, days: [SplitDay]) throws {
        try update {
            $0.answers = answers
            $0.draft = days
        }
    }

    func editCurrentSplit(now: Date, calendar: Calendar, templates: WorkoutTemplateStore = .local) throws {
        guard record.draft.isEmpty,
              let active = record.splits.last(where: { $0.effectiveDay <= dayNumber(now, calendar: calendar) })
        else { return }
        let saved = try templates.load()
        let days = active.routines.sorted { $0.key < $1.key }.compactMap { weekday, id -> SplitDay? in
            guard let source = saved.first(where: { $0.id == id }) else { return nil }
            let exercises = source.exercises.map { item in
                TemplateExercise(id: UUID(), exerciseId: item.exerciseId, targetSets: item.targetSets,
                                 repMin: item.repMin, repMax: item.repMax, initialRestSeconds: item.initialRestSeconds,
                                 position: item.position, preferredWeightUnit: item.preferredWeightUnit)
            }
            return SplitDay(weekday: weekday, template: WorkoutTemplate(id: UUID(), name: source.name,
                                                                      goal: source.goal, exercises: exercises))
        }
        guard !days.isEmpty else { return }
        var answers = record.answers
        answers.weekdays = Set(days.map(\.weekday))
        try saveDraft(answers: answers, days: days)
    }

    func activate(now: Date, calendar: Calendar, templates: WorkoutTemplateStore = .local) throws {
        let days = record.draft
        let routines = Dictionary(days.map { ($0.weekday, $0.template.id) }, uniquingKeysWith: { first, _ in first })
        guard !loadFailed, !days.isEmpty, routines.count == days.count else { throw CocoaError(.fileWriteUnknown) }
        let saved = try templates.load()
        let draftIDs = Set(routines.values)
        try templates.save(saved.filter { !draftIDs.contains($0.id) } + days.map(\.template))
        let effectiveDay = dayNumber(now, calendar: calendar)
        try update {
            $0.splits.removeAll { $0.effectiveDay >= effectiveDay }
            $0.splits.append(RecurringSplit(effectiveDay: effectiveDay, routines: routines))
            $0.welcomeCompleted = true
            $0.draft = []
        }
        revision += 1
    }

    func recurringTemplate(on date: Date, calendar: Calendar) -> UUID? {
        guard !record.skippedDates.contains(PhoneSchedule.key(for: date, calendar: calendar)) else { return nil }
        let day = dayNumber(date, calendar: calendar)
        return record.splits.last { $0.effectiveDay <= day }?.routines[calendar.component(.weekday, from: date)]
    }

    func skip(_ date: Date, calendar: Calendar) throws {
        try update { $0.skippedDates.insert(PhoneSchedule.key(for: date, calendar: calendar)) }
    }

    func startWalkthrough() throws {
        try update {
            $0.walkthrough = .start
            $0.walkthroughWorkoutID = nil
        }
    }

    func dismissWalkthrough() throws { try update { $0.walkthrough = .done } }

    func observeWorkout(active: PhoneWorkoutSummary?, completed: [PhoneWorkoutSummary]) throws {
        switch record.walkthrough {
        case .start:
            guard let active else { return }
            try update {
                $0.walkthroughWorkoutID = active.id
                $0.walkthrough = active.confirmedSets.isEmpty ? .logSet : .finish
            }
        case .logSet, .finish:
            if let active, active.id == record.walkthroughWorkoutID {
                let next: WalkthroughStep = active.confirmedSets.isEmpty ? .logSet : .finish
                if record.walkthrough != next { try update { $0.walkthrough = next } }
            } else if let session = completed.first(where: { $0.id == record.walkthroughWorkoutID }) {
                try update {
                    $0.walkthrough = session.confirmedSets.isEmpty ? .start : .viewLog
                    if session.confirmedSets.isEmpty { $0.walkthroughWorkoutID = nil }
                }
            }
        default:
            break
        }
    }

    func viewedLog() throws {
        if record.walkthrough == .viewLog { try dismissWalkthrough() }
    }

    private func dayNumber(_ date: Date, calendar: Calendar) -> Int {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let day = gregorian.dateComponents([.year, .month, .day], from: date)
        return (day.year ?? 0) * 10_000 + (day.month ?? 0) * 100 + (day.day ?? 0)
    }

    private func update(_ change: (inout TrainingSetupRecord) -> Void) throws {
        guard !loadFailed else { throw CocoaError(.fileWriteUnknown) }
        var updated = record
        change(&updated)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: url, options: .atomic)
        record = updated
    }
}
