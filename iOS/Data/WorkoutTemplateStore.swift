import Foundation

struct WorkoutTemplateStore {
    let fileURL: URL

    static var local: Self {
        Self(fileURL: RaydiunStorage.directory.appending(path: "workout-templates-v1.json"))
    }


    func load() throws -> [WorkoutTemplate] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
        return try JSONDecoder().decode([WorkoutTemplate].self, from: data)
    }

    func save(_ templates: [WorkoutTemplate]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(templates).write(to: fileURL, options: .atomic)
    }
}

enum RaydiunStorage {
    static var directory: URL {
        var directory = URL.applicationSupportDirectory
        #if DEBUG && targetEnvironment(simulator)
        if let value = ProcessInfo.processInfo.environment["RAYDIUN_UI_TEST_STORE"],
           let testID = UUID(uuidString: value) {
            directory = directory.appending(path: "UITests/\(testID.uuidString)")
        }
        #endif
        return directory
    }
}
