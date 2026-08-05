import Foundation

struct MemoryFolder: Codable, Identifiable, Hashable {
    let rawValue: String
    let customName: String?

    var id: String { rawValue }

    init(rawValue: String, customName: String? = nil) {
        self.rawValue = rawValue
        if let customName {
            self.customName = customName
        } else if rawValue.hasPrefix("custom:") {
            self.customName = String(rawValue.dropFirst("custom:".count))
        } else {
            self.customName = nil
        }
    }

    static let inbox = MemoryFolder(rawValue: "inbox")
    static let tasks = MemoryFolder(rawValue: "tasks")
    static let whatsapp = MemoryFolder(rawValue: "whatsapp")
    static let mail = MemoryFolder(rawValue: "mail")
    static let notes = MemoryFolder(rawValue: "notes")
    static let defaults = [inbox, tasks, whatsapp, mail, notes]

    static func custom(named name: String) -> MemoryFolder {
        MemoryFolder(rawValue: "custom:\(name)", customName: name)
    }

    var localizationKey: String? {
        customName == nil ? "folder_\(rawValue)" : nil
    }

    var symbolName: String {
        switch rawValue {
        case Self.inbox.rawValue: "tray"
        case Self.tasks.rawValue: "checklist"
        case Self.whatsapp.rawValue: "message"
        case Self.mail.rawValue: "envelope"
        case Self.notes.rawValue: "note.text"
        default: "folder"
        }
    }

    static func == (lhs: MemoryFolder, rhs: MemoryFolder) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

struct MemoryFilter: Identifiable, Hashable {
    let folder: MemoryFolder?

    var id: String { folder?.rawValue ?? "all" }
    static let all = MemoryFilter(folder: nil)
    static let inbox = MemoryFilter(folder: .inbox)
    static let tasks = MemoryFilter(folder: .tasks)
    static let whatsapp = MemoryFilter(folder: .whatsapp)
    static let mail = MemoryFilter(folder: .mail)
    static let notes = MemoryFilter(folder: .notes)
}

struct MemoryItem: Codable, Identifiable, Hashable {
    let id: UUID
    var text: String
    let createdAt: Date
    var updatedAt: Date
    var isDone: Bool
    var deletedAt: Date?
    var folder: String?
    var labels: [String]?

    init(
        text: String,
        folder: MemoryFolder = .inbox,
        labels: [String] = []
    ) {
        id = UUID()
        self.text = text
        createdAt = Date()
        updatedAt = Date()
        isDone = false
        deletedAt = nil
        self.folder = folder.rawValue
        self.labels = labels.isEmpty ? nil : labels
    }

    var effectiveFolder: MemoryFolder {
        if let folder, !folder.isEmpty {
            return MemoryFolder(rawValue: folder)
        }

        let normalized = text.lowercased()
        if normalized.hasPrefix("whatsapp •") { return .whatsapp }
        if normalized.hasPrefix("mail •")
            || normalized.hasPrefix("gmail •")
            || normalized.hasPrefix("thunderbird •") {
            return .mail
        }
        return .inbox
    }

    func belongs(to filter: MemoryFilter) -> Bool {
        guard let target = filter.folder else {
            return true
        }
        if target == .tasks {
            return effectiveFolder == .tasks
                || (labels ?? []).contains("tasks")
        }
        return effectiveFolder == target
    }
}

struct SyncEnvelope: Codable {
    let deviceName: String
    let items: [MemoryItem]
    let folders: [MemoryFolder]?

    init(
        deviceName: String,
        items: [MemoryItem],
        folders: [MemoryFolder]? = nil
    ) {
        self.deviceName = deviceName
        self.items = items
        self.folders = folders
    }
}
