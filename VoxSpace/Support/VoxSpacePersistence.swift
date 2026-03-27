import Foundation

struct PersistedSelection: Codable {
    let bpm: String
    let bpmMultiplier: Double
    let mode: String
    let emotion: Emotion
    let role: Role
    let isHistoryExpanded: Bool
}

struct PersistedAppState: Codable {
    let history: [HistoryItem]
    let selection: PersistedSelection?
}

enum VoxSpaceStorageKey {
    static let persistHistoryEnabled = "voxspace.persistHistoryEnabled"
}

enum VoxSpacePersistence {
    private static let directoryName = "VoxSpace"
    private static let fileName = "VoxSpaceState.json"

    static var persistenceFileURL: URL? {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        return applicationSupportURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func loadState() -> PersistedAppState? {
        guard let fileURL = persistenceFileURL,
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? JSONDecoder().decode(PersistedAppState.self, from: data)
    }

    static func saveState(history: [HistoryItem], selection: PersistedSelection?) {
        guard let fileURL = persistenceFileURL else { return }

        let directoryURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let state = PersistedAppState(history: history, selection: selection)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func clearStateFile() {
        guard let fileURL = persistenceFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
