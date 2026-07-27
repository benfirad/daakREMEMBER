import Foundation

enum SharedStorage {
    static let appGroup = Bundle.main.object(
        forInfoDictionaryKey: "AklimaGeldiAppGroup"
    ) as? String ?? "group.dev.abim.aklimageldi"
    static let fileName = "items.json"

    static var fileURL: URL {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        ) {
            return groupURL.appendingPathComponent(fileName)
        }

        let fallback = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("AklimaGeldi", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: fallback,
            withIntermediateDirectories: true
        )
        return fallback.appendingPathComponent(fileName)
    }

    static func load() -> [MemoryItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([MemoryItem].self, from: data)
        else {
            return []
        }
        return items
    }

    static func save(_ items: [MemoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func migrateLegacyDataIfNeeded() {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let legacy = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent("AklimaGeldi", isDirectory: true)
            .appendingPathComponent(fileName)
        guard legacy != fileURL,
              let data = try? Data(contentsOf: legacy)
        else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
