import Foundation
import Combine
import WidgetKit

@MainActor
final class MemoryStore: ObservableObject {
    static let deletedItemRetention: TimeInterval = 24 * 60 * 60

    @Published private(set) var items: [MemoryItem] = []
    @Published private(set) var lastSync: Date?
    @Published private(set) var syncMessageKey = "sync_waiting"
    @Published private(set) var syncMessageArguments: [String] = []
    private let saveItems: ([MemoryItem]) -> Void
    private var purgeTimer: Timer?

    init(
        initialItems: [MemoryItem]? = nil,
        saveItems: @escaping ([MemoryItem]) -> Void = SharedStorage.save
    ) {
        self.saveItems = saveItems
        if let initialItems {
            items = initialItems
        } else {
            SharedStorage.migrateLegacyDataIfNeeded()
            load()
        }
        purgeExpiredDeletions()
    }

    var visibleItems: [MemoryItem] {
        items
            .filter { $0.deletedAt == nil }
            .sorted {
                if $0.isDone != $1.isDone { return !$0.isDone }
                return $0.updatedAt > $1.updatedAt
            }
    }

    func visibleItems(in filter: MemoryFilter) -> [MemoryItem] {
        visibleItems.filter { $0.belongs(to: filter) }
    }

    func count(in filter: MemoryFilter) -> Int {
        visibleItems.reduce(into: 0) { count, item in
            if item.belongs(to: filter) { count += 1 }
        }
    }

    func add(_ rawText: String, folder: MemoryFolder = .inbox) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        items.append(MemoryItem(text: text, folder: folder))
        persist()
    }

    func move(_ id: UUID, to folder: MemoryFolder) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].folder = folder.rawValue
        if folder == .tasks {
            var labels = Set(items[index].labels ?? [])
            labels.insert("tasks")
            items[index].labels = Array(labels).sorted()
        } else if var labels = items[index].labels {
            labels.removeAll { $0 == "tasks" }
            items[index].labels = labels.isEmpty ? nil : labels
        }
        items[index].updatedAt = Date()
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
        scheduleNextPurge(now: now)
    }

    func restore(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].deletedAt != nil
        else {
            return
        }
        items[index].deletedAt = nil
        items[index].updatedAt = Date()
        persist()
        scheduleNextPurge()
    }

    @discardableResult
    func purgeExpiredDeletions(now: Date = Date()) -> Int {
        let cutoff = now.addingTimeInterval(-Self.deletedItemRetention)
        let originalCount = items.count
        items.removeAll { item in
            guard let deletedAt = item.deletedAt else { return false }
            return deletedAt <= cutoff
        }
        let purgedCount = originalCount - items.count
        if purgedCount > 0 {
            persist()
        }
        scheduleNextPurge(now: now)
        return purgedCount
    }

    func snapshot() -> [MemoryItem] {
        purgeExpiredDeletions()
        return items
    }

    func merge(_ incoming: [MemoryItem], from device: String) {
        let now = Date()
        purgeExpiredDeletions(now: now)
        let cutoff = now.addingTimeInterval(-Self.deletedItemRetention)
        var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var changed = false

        for candidate in incoming {
            if let deletedAt = candidate.deletedAt, deletedAt <= cutoff {
                continue
            }
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
        scheduleNextPurge(now: now)
        lastSync = Date()
        setSyncMessage("sync_synced_format", arguments: [device])
    }

    func setSyncMessage(_ key: String, arguments: [String] = []) {
        syncMessageKey = key
        syncMessageArguments = arguments
    }

    func markSyncReady() {
        if lastSync == nil {
            setSyncMessage("sync_ready")
        }
    }

    func markClientConnected() {
        lastSync = Date()
        setSyncMessage("sync_client_connected")
    }

    private func load() {
        items = SharedStorage.load()
    }

    private func persist() {
        saveItems(items)
        WidgetCenter.shared.reloadTimelines(ofKind: "AklimaGeldiWidget")
        WidgetCenter.shared.reloadAllTimelines()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WidgetCenter.shared.reloadTimelines(ofKind: "AklimaGeldiWidget")
        }
    }

    private func scheduleNextPurge(now: Date = Date()) {
        purgeTimer?.invalidate()
        purgeTimer = nil
        guard let nextDeletion = items.compactMap(\.deletedAt).min() else { return }
        let deadline = nextDeletion.addingTimeInterval(Self.deletedItemRetention)
        let delay = max(deadline.timeIntervalSince(now), 1)
        purgeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.purgeExpiredDeletions()
            }
        }
    }
}
