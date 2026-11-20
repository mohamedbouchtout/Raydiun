import Foundation

enum WorkoutGoal: String, Codable, Sendable {
    case strength, hypertrophy, endurance
}

enum ExerciseSupportTier: String, Codable, Sendable {
    case candidate, trained, watchTested, autoEnabled, manualOnly
}

enum WeightUnit: String, Codable, Sendable {
    case kg, lb

    fileprivate var kilogramsPerUnit: Double {
        switch self {
        case .kg: 1
        case .lb: 0.45359237
        }
    }
}

struct WorkoutWeight: Codable, Equatable, Sendable {
    let kilograms: Double
    let displayUnit: WeightUnit

    init?(value: Double, unit: WeightUnit) {
        guard value.isFinite, value >= 0 else { return nil }
        kilograms = value * unit.kilogramsPerUnit
        displayUnit = unit
    }

    func value(in unit: WeightUnit) -> Double {
        kilograms / unit.kilogramsPerUnit
    }

    private enum CodingKeys: String, CodingKey {
        case kilograms, displayUnit
    }

    init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let value = try fields.decode(Double.self, forKey: .kilograms)
        guard value.isFinite, value >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .kilograms, in: fields, debugDescription: "Expected finite, nonnegative kilograms."
            )
        }
        kilograms = value
        displayUnit = try fields.decode(WeightUnit.self, forKey: .displayUnit)
    }
}

struct ExerciseDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var movementCategory: String
    var supportTier: ExerciseSupportTier
    let isCustom: Bool
    let createdAt: Date

    var supportedAutoRecognition: Bool { supportTier == .autoEnabled }
}

struct WorkoutTemplate: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var goal: WorkoutGoal
    var exercises: [TemplateExercise]
}

struct TemplateExercise: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var exerciseId: UUID
    var targetSets: Int
    var repMin: Int
    var repMax: Int
    var initialRestSeconds: Int
    var position: Int
    var preferredWeightUnit: WeightUnit
}

enum WorkoutStatus: String, Codable, Sendable {
    case idle, preparing, trackingSet, candidateSetEnd, resting, paused, finished
}

struct WorkoutSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let templateId: UUID?
    let startedAt: Date
    var endedAt: Date?
    let timeZoneAtStart: String
    let originDeviceId: UUID
    var status: WorkoutStatus
    let planSnapshotVersion: Int?
}

enum LabelSource: String, Codable, Sendable {
    case manual, model, confirmed
}

enum RepSource: String, Codable, Sendable {
    case manual, inferred, confirmed
}

struct ExercisePerformance: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sessionId: UUID
    var exerciseId: UUID?
    let positionObserved: Int
    var labelSource: LabelSource
    var modelVersion: String?
    var confidence: Double?
    var startedAt: Date?
    var endedAt: Date?
}

struct SetRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let performanceId: UUID
    let index: Int
    var reps: Int
    var weight: WorkoutWeight?
    var startedAt: Date?
    var endedAt: Date?
    var restStartedAt: Date?
    var restSeconds: Int?
    var repsSource: RepSource
    var repsConfidence: Double?
    var confirmed: Bool
    var userNotes: String?
}

enum RawSensorRetention: Codable, Equatable, Sendable {
    case disabled
    case expireAfter(days: Int)
}

struct UserSettings: Codable, Equatable, Sendable {
    var goalDefault: WorkoutGoal = .hypertrophy
    var units: WeightUnit = .kg
    var autoRecognition = false
    var haptics = true
    var sound = false
    var rawSensorRetention: RawSensorRetention = .disabled
    var preferredRestByGoal: [String: Int] = [:]
}

struct ModelMetadata: Codable, Equatable, Sendable {
    struct ClassMetrics: Codable, Equatable, Sendable {
        let precision: Double
        let recall: Double
        let support: Int
    }

    let identifier: String
    let version: String
    let trainedClasses: [UUID]
    let watchValidatedClasses: [UUID]
    let autoEnabledClasses: [UUID]
    let perClassMetrics: [String: ClassMetrics]
    let samplingHz: Double
    let windowLength: Int
    let requiredChannels: [String]
    let evaluationSummary: String
    let provenance: String
}

struct MotionRecording: Identifiable, Codable, Equatable, Sendable {
    struct SamplingStats: Codable, Equatable, Sendable {
        let observedHz: Double
        let sampleCount: Int
        let gapCount: Int
    }

    let id: UUID
    let sessionId: UUID
    let startedAt: Date
    let samplingStats: SamplingStats
    let fileLocation: String
    let retentionPolicy: RawSensorRetention
    let userConfirmedLabel: UUID?
}
