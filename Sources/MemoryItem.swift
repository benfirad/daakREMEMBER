import Foundation

enum MemoryFolder: String, Codable, CaseIterable, Identifiable {
    case inbox
    case tasks
    case whatsapp
    case mail
    case notes

    var id: String { rawValue }

    var localizationKey: String { "folder_\(rawValue)" }

    var symbolName: String {
        switch self {
        case .inbox: "tray"
        case .tasks: "checklist"
        case .whatsapp: "message"
        case .mail: "envelope"
        case .notes: "note.text"
        }
    }
}

enum MemoryFilter: String, CaseIterable, Identifiable {
    case all
    case inbox
    case tasks
    case whatsapp
    case mail
    case notes

    var id: String { rawValue }
    var localizationKey: String { "folder_\(rawValue)" }
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
        if let folder, let value = MemoryFolder(rawValue: folder) {
            return value
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
        switch filter {
        case .all:
            return true
        case .tasks:
            return effectiveFolder == .tasks
                || (labels ?? []).contains("tasks")
        case .inbox:
            return effectiveFolder == .inbox
        case .whatsapp:
            return effectiveFolder == .whatsapp
        case .mail:
            return effectiveFolder == .mail
        case .notes:
            return effectiveFolder == .notes
        }
    }
}

struct SyncEnvelope: Codable {
    let deviceName: String
    let items: [MemoryItem]
}
