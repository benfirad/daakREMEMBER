import Foundation

enum SharedStorage {
    static let appGroup = Bundle.main.object(
        forInfoDictionaryKey: "AklimaGeldiAppGroup"
    ) as? String ?? "group.dev.abim.aklimageldi"
    static let fileName = "items.json"
    static let foldersFileName = "folders.json"
    private static let captureFolderKey = "captureFolder"

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

    static var foldersFileURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent(foldersFileName)
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

    static func loadFolders() -> [MemoryFolder]? {
        guard let data = try? Data(contentsOf: foldersFileURL) else { return nil }
        return try? JSONDecoder().decode([MemoryFolder].self, from: data)
    }

    static func saveFolders(_ folders: [MemoryFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        try? data.write(to: foldersFileURL, options: .atomic)
    }

    static func selectedCaptureFolder() -> MemoryFolder {
        let shared = UserDefaults(suiteName: appGroup)?
            .string(forKey: captureFolderKey)
        let local = UserDefaults.standard.string(forKey: captureFolderKey)
        let rawValue = shared ?? local ?? ""
        return rawValue.isEmpty ? .inbox : MemoryFolder(rawValue: rawValue)
    }

    static func saveCaptureFolder(_ folder: MemoryFolder) {
        UserDefaults.standard.set(folder.rawValue, forKey: captureFolderKey)
        UserDefaults(suiteName: appGroup)?
            .set(folder.rawValue, forKey: captureFolderKey)
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
