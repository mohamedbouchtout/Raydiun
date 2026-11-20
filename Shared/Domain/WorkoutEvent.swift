import Foundation

struct WorkoutEvent: Identifiable, Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    enum Payload: Codable, Equatable, Sendable {
        case sessionStarted(session: WorkoutSession)
        case sessionStatusChanged(status: WorkoutStatus)
        case exerciseRecorded(performance: ExercisePerformance)
        case setRecorded(set: SetRecord)
        case setCorrected(set: SetRecord)
        case exerciseCorrected(performance: ExercisePerformance)
    }

    enum SchemaError: Error, Equatable {
        case unsupportedVersion(Int)
    }

    let eventId: UUID
    let sessionId: UUID
    let deviceId: UUID
    let sequence: UInt64
    let recordedAt: Date
    let payload: Payload
    let supersedesEventId: UUID?
    let schemaVersion: Int

    var id: UUID { eventId }

    init(
        eventId: UUID = UUID(), sessionId: UUID, deviceId: UUID, sequence: UInt64,
        recordedAt: Date, payload: Payload, supersedesEventId: UUID? = nil
    ) {
        self.eventId = eventId
        self.sessionId = sessionId
        self.deviceId = deviceId
        self.sequence = sequence
        self.recordedAt = recordedAt
        self.payload = payload
        self.supersedesEventId = supersedesEventId
        schemaVersion = Self.currentSchemaVersion
    }

    private enum CodingKeys: String, CodingKey {
        case eventId, sessionId, deviceId, sequence, recordedAt, payload, supersedesEventId, schemaVersion
    }

    init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try fields.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw SchemaError.unsupportedVersion(schemaVersion)
        }
        eventId = try fields.decode(UUID.self, forKey: .eventId)
        sessionId = try fields.decode(UUID.self, forKey: .sessionId)
        deviceId = try fields.decode(UUID.self, forKey: .deviceId)
        sequence = try fields.decode(UInt64.self, forKey: .sequence)
        recordedAt = try fields.decode(Date.self, forKey: .recordedAt)
        payload = try fields.decode(Payload.self, forKey: .payload)
        supersedesEventId = try fields.decodeIfPresent(UUID.self, forKey: .supersedesEventId)
    }
}
