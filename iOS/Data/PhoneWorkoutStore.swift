import Foundation
import Observation

// The journal is the source of truth. A command is one atomic file replacement, even when
// it contains several domain events; failed writes never change the published read model.
private struct PhoneWorkoutCommand: Codable {
    let id: UUID
    let sessionId: UUID
    let changes: [PhoneWorkoutChange]
}

private enum PhoneWorkoutChange: Codable {
    case domain(WorkoutEvent)
    case title(String)
    case exerciseName(UUID, String)
    case restEnd(Date?)
    case undoSet(UUID)
    case ended(Date)
}

struct PhoneWorkoutExercise: Identifiable {
    let performance: ExercisePerformance
    var name: String
    var sets: [SetRecord] = []
    var id: UUID { performance.id }
}

struct PhoneWorkoutSummary: Identifiable {
    var session: WorkoutSession
    var title: String
    var exercises: [PhoneWorkoutExercise] = []
    var restEnd: Date?
    var id: UUID { session.id }
    var confirmedSets: [SetRecord] { exercises.flatMap(\.sets).filter(\.confirmed) }
}

@MainActor
@Observable
final class PhoneWorkoutStore {
    enum StoreError: LocalizedError {
        case unavailable, activeSession, noActiveSession, invalidState, invalidSet, invalidInput

        var errorDescription: String? {
            switch self {
            case .unavailable: "Workout history could not be read. No changes were made."
            case .activeSession: "Finish the current workout before starting another."
            case .noActiveSession: "There is no active workout."
            case .invalidState: "This action is not available in the current workout state."
            case .invalidSet: "That set is no longer available."
            case .invalidInput: "Enter valid reps and a nonnegative weight."
            }
        }
    }

    private let fileURL: URL
    private var journal: [PhoneWorkoutCommand] = []
    private(set) var sessions: [PhoneWorkoutSummary] = []
    private(set) var loadError: String?
    private let deviceId: UUID

    var active: PhoneWorkoutSummary? { sessions.first { $0.session.endedAt == nil } }
    var completed: [PhoneWorkoutSummary] {
        sessions.filter { $0.session.endedAt != nil }.sorted { $0.session.startedAt > $1.session.startedAt }
    }

    init(fileURL: URL = RaydiunStorage.directory.appending(path: "phone-workouts-v1.json")) {
        self.fileURL = fileURL
        deviceId = UUID()
        do {
            let data = try Data(contentsOf: fileURL)
            journal = try JSONDecoder().decode([PhoneWorkoutCommand].self, from: data)
            guard Set(journal.map(\.id)).count == journal.count else { throw StoreError.unavailable }
            sessions = Self.project(journal)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // A missing file is a fresh installation; other read/decode failures block writes.
        } catch {
            loadError = error.localizedDescription
        }
    }

    func start(template: WorkoutTemplate?, library: ExerciseLibrary, commandId: UUID = UUID(), now: Date = Date()) throws {
        if journal.contains(where: { $0.id == commandId }) { return }
        guard active == nil else { throw StoreError.activeSession }
        let id = UUID()
        let session = WorkoutSession(
            id: id, templateId: template?.id, startedAt: now, endedAt: nil,
            timeZoneAtStart: TimeZone.current.identifier, originDeviceId: deviceId,
            status: .trackingSet, planSnapshotVersion: template == nil ? nil : 1
        )
        var changes: [PhoneWorkoutChange] = [
            .domain(event(id, .sessionStarted(session: session), now)),
            .title(template?.name ?? "Manual Workout")
        ]
        for (index, item) in (template?.exercises.sorted { $0.position < $1.position } ?? []).enumerated() {
            let performance = ExercisePerformance(
                id: UUID(), sessionId: id, exerciseId: item.exerciseId, positionObserved: index,
                labelSource: .manual, modelVersion: nil, confidence: nil, startedAt: now, endedAt: nil
            )
            changes.append(.domain(event(id, .exerciseRecorded(performance: performance), now, offset: index + 1)))
            changes.append(.exerciseName(performance.id, library.name(for: item.exerciseId)))
        }
        try commit(commandId, sessionId: id, changes: changes)
    }

    func addExercise(_ definition: ExerciseDefinition, commandId: UUID = UUID(), now: Date = Date()) throws {
        if journal.contains(where: { $0.id == commandId }) { return }
        let workout = try workingSession()
        let performance = ExercisePerformance(
            id: UUID(), sessionId: workout.id, exerciseId: definition.id,
            positionObserved: workout.exercises.count, labelSource: .manual,
            modelVersion: nil, confidence: nil, startedAt: now, endedAt: nil
        )
        try commit(commandId, sessionId: workout.id, changes: [
            .domain(event(workout.id, .exerciseRecorded(performance: performance), now)),
            .exerciseName(performance.id, definition.name)
        ])
    }

    func recordSet(performanceId: UUID, reps: Int, weight: WorkoutWeight?, commandId: UUID = UUID(), now: Date = Date()) throws {
        if journal.contains(where: { $0.id == commandId }) { return }
        let workout = try workingSession()
        guard reps > 0 && reps <= 999 else { throw StoreError.invalidInput }
        guard let exercise = workout.exercises.first(where: { $0.id == performanceId }) else { throw StoreError.invalidState }
        let set = SetRecord(
            id: UUID(), performanceId: performanceId, index: exercise.sets.count + 1,
            reps: reps, weight: weight, startedAt: now, endedAt: now,
            restStartedAt: nil, restSeconds: nil, repsSource: .manual,
            repsConfidence: nil, confirmed: true, userNotes: nil
        )
        try commit(commandId, sessionId: workout.id, changes: [
            .domain(event(workout.id, .setRecorded(set: set), now)), .restEnd(nil),
            .domain(event(workout.id, .sessionStatusChanged(status: .trackingSet), now, offset: 1))
        ])
    }

    func editSet(_ setId: UUID, reps: Int, weight: WorkoutWeight?, commandId: UUID = UUID(), now: Date = Date()) throws {
        if journal.contains(where: { $0.id == commandId }) { return }
        let workout = try workingSession()
        guard reps > 0 && reps <= 999 else { throw StoreError.invalidInput }
        guard let old = workout.exercises.flatMap(\.sets).first(where: { $0.id == setId }) else { throw StoreError.invalidSet }
        var updated = old
        updated.reps = reps
        updated.weight = weight
        try commit(commandId, sessionId: workout.id, changes: [.domain(event(workout.id, .setCorrected(set: updated), now))])
    }

    func undoSet(_ setId: UUID, commandId: UUID = UUID()) throws {
        if journal.contains(where: { $0.id == commandId }) { return }
        let workout = try workingSession()
        guard workout.exercises.flatMap(\.sets).contains(where: { $0.id == setId }) else { throw StoreError.invalidSet }
        try commit(commandId, sessionId: workout.id, changes: [.undoSet(setId)])
    }

    func rest(seconds: Int, commandId: UUID = UUID(), now: Date = Date()) throws {
        if journal.contains(where: { $0.id == commandId }) { return }
        let workout = try workingSession()
        guard (1...3600).contains(seconds) else { throw StoreError.invalidInput }
        try commit(commandId, sessionId: workout.id, changes: [
            .restEnd(now.addingTimeInterval(TimeInterval(seconds))),
            .domain(event(workout.id, .sessionStatusChanged(status: .resting), now))
        ])
    }

    func pause(commandId: UUID = UUID(), now: Date = Date()) throws {
        if journal.contains(where: { $0.id == commandId }) { return }
        let workout = try workingSession()
        try commit(commandId, sessionId: workout.id, changes: [
            .domain(event(workout.id, .sessionStatusChanged(status: .paused), now))
        ])
    }

    func resume(commandId: UUID = UUID(), now: Date = Date()) throws {
        if journal.contains(where: { $0.id == commandId }) { return }
        guard let workout = active else { throw StoreError.noActiveSession }
        guard workout.session.status == .paused else { throw StoreError.invalidState }
        let resting = (workout.restEnd ?? .distantPast) > now
        try commit(commandId, sessionId: workout.id, changes: [
            .domain(event(workout.id, .sessionStatusChanged(status: resting ? .resting : .trackingSet), now))
        ])
    }

    func finish(commandId: UUID = UUID(), now: Date = Date()) throws {
        if journal.contains(where: { $0.id == commandId }) { return }
        guard let workout = active else { throw StoreError.noActiveSession }
        try commit(commandId, sessionId: workout.id, changes: [
            .restEnd(nil), .ended(now),
            .domain(event(workout.id, .sessionStatusChanged(status: .finished), now))
        ])
    }

    private func workingSession() throws -> PhoneWorkoutSummary {
        guard let workout = active else { throw StoreError.noActiveSession }
        guard workout.session.status != .paused else { throw StoreError.invalidState }
        return workout
    }

    private func event(_ sessionId: UUID, _ payload: WorkoutEvent.Payload, _ now: Date, offset: Int = 0) -> WorkoutEvent {
        let domainCount = journal.reduce(0) { count, command in
            count + command.changes.filter { if case .domain = $0 { return true }; return false }.count
        }
        return WorkoutEvent(sessionId: sessionId, deviceId: deviceId,
                            sequence: UInt64(domainCount + offset + 1), recordedAt: now, payload: payload)
    }

    private func commit(_ id: UUID, sessionId: UUID, changes: [PhoneWorkoutChange]) throws {
        guard loadError == nil else { throw StoreError.unavailable }
        if journal.contains(where: { $0.id == id }) { return } // Retried command, including after relaunch.
        let next = journal + [PhoneWorkoutCommand(id: id, sessionId: sessionId, changes: changes)]
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: fileURL, options: .atomic)
        journal = next
        sessions = Self.project(next)
    }

    private static func project(_ commands: [PhoneWorkoutCommand]) -> [PhoneWorkoutSummary] {
        var result: [PhoneWorkoutSummary] = []
        for command in commands {
            for change in command.changes {
                if case let .domain(event) = change, case let .sessionStarted(session) = event.payload {
                    result.append(PhoneWorkoutSummary(session: session, title: "Manual Workout"))
                    continue
                }
                guard let index = result.firstIndex(where: { $0.id == command.sessionId }) else { continue }
                switch change {
                case let .domain(event):
                    switch event.payload {
                    case let .sessionStatusChanged(status): result[index].session.status = status
                    case let .exerciseRecorded(performance):
                        result[index].exercises.append(PhoneWorkoutExercise(performance: performance, name: "Exercise"))
                    case let .setRecorded(set), let .setCorrected(set):
                        if let exerciseIndex = result[index].exercises.firstIndex(where: { $0.id == set.performanceId }) {
                            if let setIndex = result[index].exercises[exerciseIndex].sets.firstIndex(where: { $0.id == set.id }) {
                                result[index].exercises[exerciseIndex].sets[setIndex] = set
                            } else {
                                result[index].exercises[exerciseIndex].sets.append(set)
                            }
                        }
                    case .sessionStarted, .exerciseCorrected: break
                    }
                case let .title(title): result[index].title = title
                case let .exerciseName(id, name):
                    if let exerciseIndex = result[index].exercises.firstIndex(where: { $0.id == id }) {
                        result[index].exercises[exerciseIndex].name = name
                    }
                case let .restEnd(date): result[index].restEnd = date
                case let .undoSet(id):
                    for exerciseIndex in result[index].exercises.indices {
                        result[index].exercises[exerciseIndex].sets.removeAll { $0.id == id }
                    }
                case let .ended(date): result[index].session.endedAt = date
                }
            }
        }
        return result
    }
}
