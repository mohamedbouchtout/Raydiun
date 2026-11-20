import Foundation
import Testing
@testable import RaydiunDomain

struct WorkoutModelTests {
    @Test func weightStoresKilogramsAndKeepsDisplayUnit() throws {
        let weight = try #require(WorkoutWeight(value: 100, unit: .lb))
        let decoded = try JSONDecoder().decode(WorkoutWeight.self, from: JSONEncoder().encode(weight))
        #expect(decoded == weight)
        #expect(decoded.displayUnit == .lb)
        #expect(abs(decoded.kilograms - 45.359237) < 0.000001)
        #expect(abs(decoded.value(in: .lb) - 100) < 0.000001)
        #expect(WorkoutWeight(value: -.infinity, unit: .kg) == nil)
        #expect(WorkoutWeight(value: -1, unit: .kg) == nil)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                WorkoutWeight.self, from: Data(#"{"kilograms":-1,"displayUnit":"lb"}"#.utf8)
            )
        }
    }

    @Test func currentSchemaDecodesStableFixture() throws {
        let data = Data("""
        {
          "schemaVersion": 1,
          "eventId": "00000000-0000-0000-0000-000000000001",
          "sessionId": "00000000-0000-0000-0000-000000000002",
          "deviceId": "00000000-0000-0000-0000-000000000003",
          "sequence": 1, "recordedAt": 0,
          "payload": {"sessionStatusChanged":{"status":"paused"}}
        }
        """.utf8)
        let event = try JSONDecoder().decode(WorkoutEvent.self, from: data)
        #expect(event.id.uuidString == "00000000-0000-0000-0000-000000000001")
        #expect(event.payload == .sessionStatusChanged(status: .paused))
        #expect(event.recordedAt == Date(timeIntervalSinceReferenceDate: 0))
    }

    @Test func eventRoundTripPreservesIdentityAndCorrectionProvenance() throws {
        let record = SetRecord(
            id: UUID(), performanceId: UUID(), index: 1, reps: 8,
            weight: WorkoutWeight(value: 20, unit: .kg), repsSource: .inferred,
            repsConfidence: 0.8, confirmed: false
        )
        let started = WorkoutEvent(
            sessionId: UUID(), deviceId: UUID(), sequence: 1, recordedAt: Date(),
            payload: .setRecorded(set: record)
        )
        var correctedRecord = record
        correctedRecord.reps = 9
        correctedRecord.repsSource = .confirmed
        correctedRecord.repsConfidence = nil
        correctedRecord.confirmed = true
        let correction = WorkoutEvent(
            sessionId: started.sessionId, deviceId: started.deviceId, sequence: 2, recordedAt: Date(),
            payload: .setCorrected(set: correctedRecord), supersedesEventId: started.id
        )
        let events = [started, correction]
        let decoded = try JSONDecoder().decode([WorkoutEvent].self, from: JSONEncoder().encode(events))
        #expect(Set(decoded.map(\.id)).count == 2)
        #expect(decoded == events)
    }

    @Test(arguments: [0, 2])
    func rejectsUnsupportedSchemaBeforeDecodingPayload(version: Int) {
        let data = Data(#"{"schemaVersion":\#(version),"payload":{"unrecognized":true}}"#.utf8)
        #expect(throws: WorkoutEvent.SchemaError.unsupportedVersion(version)) {
            try JSONDecoder().decode(WorkoutEvent.self, from: data)
        }
    }
}
