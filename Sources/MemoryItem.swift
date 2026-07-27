import Foundation

struct MemoryItem: Codable, Identifiable, Hashable {
    let id: UUID
    var text: String
    let createdAt: Date
    var updatedAt: Date
    var isDone: Bool
    var deletedAt: Date?

    init(text: String) {
        id = UUID()
        self.text = text
        createdAt = Date()
        updatedAt = Date()
        isDone = false
        deletedAt = nil
    }
}

struct SyncEnvelope: Codable {
    let deviceName: String
    let items: [MemoryItem]
}
