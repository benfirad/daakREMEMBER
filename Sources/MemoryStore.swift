import Foundation
import Combine

@MainActor
final class MemoryStore: ObservableObject {
    @Published private(set) var items: [MemoryItem] = []
    @Published private(set) var lastSync: Date?
    @Published private(set) var syncMessage = "Tailscale bekleniyor"

    private let fileURL: URL

    init() {
        let manager = FileManager.default
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AklimaGeldi", isDirectory: true)
        try? manager.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("items.json")
        load()
    }

    var visibleItems: [MemoryItem] {
        items
            .filter { $0.deletedAt == nil }
            .sorted {
                if $0.isDone != $1.isDone { return !$0.isDone }
                return $0.updatedAt > $1.updatedAt
            }
    }

    func add(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        items.append(MemoryItem(text: text))
        persist()
    }

    func toggle(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isDone.toggle()
        items[index].updatedAt = Date()
        persist()
    }

    func remove(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        items[index].deletedAt = now
        items[index].updatedAt = now
        persist()
    }

    func snapshot() -> [MemoryItem] {
        items
    }

    func merge(_ incoming: [MemoryItem], from device: String) {
        var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var changed = false

        for candidate in incoming {
            if let current = byID[candidate.id] {
                if candidate.updatedAt > current.updatedAt {
                    byID[candidate.id] = candidate
                    changed = true
                }
            } else {
                byID[candidate.id] = candidate
                changed = true
            }
        }

        if changed {
            items = Array(byID.values)
            persist()
        }
        lastSync = Date()
        syncMessage = "\(device) ile eşitlendi"
    }

    func setSyncMessage(_ message: String) {
        syncMessage = message
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([MemoryItem].self, from: data) else { return }
        items = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
