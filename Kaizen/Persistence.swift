import Foundation

struct PersistenceStore {
    private let directory: URL
    private let checklistURL: URL
    private let preferencesURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        directory = base.appendingPathComponent("Kaizen", isDirectory: true)
        checklistURL = directory.appendingPathComponent("checklist.json")
        preferencesURL = directory.appendingPathComponent("preferences.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadChecklist() -> [ChecklistItem] {
        decode(from: checklistURL) ?? []
    }

    func saveChecklist(_ items: [ChecklistItem]) {
        encode(items, to: checklistURL)
    }

    func loadPreferences() -> Preferences {
        decode(from: preferencesURL) ?? .default
    }

    func savePreferences(_ preferences: Preferences) {
        encode(preferences, to: preferencesURL)
    }

    private func decode<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
