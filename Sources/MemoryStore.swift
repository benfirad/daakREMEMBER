import Foundation
import Combine
import WidgetKit

@MainActor
final class MemoryStore: ObservableObject {
    @Published private(set) var items: [MemoryItem] = []
    @Published private(set) var lastSync: Date?
    @Published private(set) var syncMessageKey = "sync_waiting"
    @Published private(set) var syncMessageArguments: [String] = []

    init() {
        SharedStorage.migrateLegacyDataIfNeeded()
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
        setSyncMessage("sync_synced_format", arguments: [device])
    }

    func setSyncMessage(_ key: String, arguments: [String] = []) {
        syncMessageKey = key
        syncMessageArguments = arguments
    }

    private func load() {
        items = SharedStorage.load()
    }

    private func persist() {
        SharedStorage.save(items)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
