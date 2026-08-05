import Foundation
import XCTest
@testable import AklimaGeldi

final class MemoryItemTests: XCTestCase {
    func testCaptureDraftKeepsSelectedFolderForEnterAndButtonPath() {
        let draft = CaptureDraft(folder: .notes, persistsFolder: false)
        draft.text = "  Kitap fikrini yaz  "

        let capture = draft.consume()

        XCTAssertEqual(capture?.text, "Kitap fikrini yaz")
        XCTAssertEqual(capture?.folder, .notes)
        XCTAssertEqual(draft.text, "")
        XCTAssertEqual(draft.folder, .notes)
    }

    @MainActor
    func testStoreFolderLifecycleAddMoveCompleteDeleteAndMerge() {
        var saved: [[MemoryItem]] = []
        let store = MemoryStore(initialItems: [], saveItems: { saved.append($0) })

        store.add("Mailden gelen görev", folder: .mail)
        let id = try! XCTUnwrap(store.visibleItems.first?.id)
        XCTAssertEqual(store.visibleItems.first?.effectiveFolder, .mail)
        XCTAssertEqual(store.count(in: .mail), 1)

        store.move(id, to: .tasks)
        XCTAssertEqual(store.visibleItems.first?.effectiveFolder, .tasks)
        XCTAssertTrue(store.visibleItems.first?.labels?.contains("tasks") == true)

        store.toggle(id)
        XCTAssertTrue(store.visibleItems.first?.isDone == true)

        var remote = try! XCTUnwrap(store.snapshot().first)
        remote.text = "Telefonda güncellendi"
        remote.updatedAt = Date().addingTimeInterval(2)
        store.merge([remote], from: "DAAK NODE")
        XCTAssertEqual(store.visibleItems.first?.text, "Telefonda güncellendi")

        store.remove(id)
        XCTAssertTrue(store.visibleItems.isEmpty)
        XCTAssertGreaterThanOrEqual(saved.count, 5)
    }

    @MainActor
    func testSoftDeletedItemCanBeRestored() {
        let store = MemoryStore(initialItems: [], saveItems: { _ in })
        store.add("Geri alınacak madde")
        let id = try! XCTUnwrap(store.visibleItems.first?.id)

        store.remove(id)
        XCTAssertTrue(store.visibleItems.isEmpty)
        XCTAssertNotNil(store.snapshot().first?.deletedAt)

        store.restore(id)
        XCTAssertEqual(store.visibleItems.map(\.id), [id])
        XCTAssertNil(store.snapshot().first?.deletedAt)
    }

    @MainActor
    func testDeletedItemsArePermanentlyPurgedAfter24Hours() {
        let now = Date()
        var expired = MemoryItem(text: "Süresi dolmuş")
        expired.deletedAt = now.addingTimeInterval(
            -MemoryStore.deletedItemRetention - 1
        )
        expired.updatedAt = expired.deletedAt!

        var recent = MemoryItem(text: "Henüz 24 saat olmadı")
        recent.deletedAt = now.addingTimeInterval(-1)
        recent.updatedAt = recent.deletedAt!

        var saved: [[MemoryItem]] = []
        let store = MemoryStore(initialItems: [expired, recent], saveItems: {
            saved.append($0)
        })

        XCTAssertEqual(store.snapshot().map(\.id), [recent.id])
        XCTAssertEqual(saved.last?.map(\.id), [recent.id])

        let purged = store.purgeExpiredDeletions(
            now: now.addingTimeInterval(MemoryStore.deletedItemRetention)
        )
        XCTAssertEqual(purged, 1)
        XCTAssertTrue(store.snapshot().isEmpty)
    }

    @MainActor
    func testMergeIgnoresExpiredRemoteTombstones() {
        let now = Date()
        var expired = MemoryItem(text: "Uzak cihazın eski silinmiş maddesi")
        expired.deletedAt = now.addingTimeInterval(
            -MemoryStore.deletedItemRetention - 1
        )
        expired.updatedAt = expired.deletedAt!
        let store = MemoryStore(initialItems: [], saveItems: { _ in })

        store.merge([expired], from: "Eski Mac")

        XCTAssertTrue(store.snapshot().isEmpty)
    }

    @MainActor
    func testCustomFoldersCanBeAddedDeletedAndMoved() {
        var savedFolders: [[MemoryFolder]] = []
        let store = MemoryStore(
            initialItems: [],
            initialFolders: [.inbox, .notes],
            saveFolders: { savedFolders.append($0) },
            saveItems: { _ in }
        )

        let projects = try! XCTUnwrap(store.addFolder("Projeler"))
        store.add("Teklif dosyasını hazırla", folder: projects)

        XCTAssertEqual(store.activeItemCount(in: projects), 1)
        XCTAssertFalse(store.deleteFolder(projects, movingItemsTo: nil))
        XCTAssertTrue(store.deleteFolder(projects, movingItemsTo: .notes))
        XCTAssertFalse(store.folders.contains(projects))
        XCTAssertEqual(store.visibleItems.first?.effectiveFolder, .notes)
        XCTAssertFalse(savedFolders.last?.contains(projects) == true)

        let empty = try! XCTUnwrap(store.addFolder("Boş klasör"))
        XCTAssertTrue(store.deleteFolder(empty, movingItemsTo: nil))
        XCTAssertFalse(store.folders.contains(empty))
    }

    @MainActor
    func testLastFolderCannotBeDeleted() {
        let store = MemoryStore(
            initialItems: [],
            initialFolders: [.inbox],
            saveItems: { _ in }
        )

        XCTAssertFalse(store.deleteFolder(.inbox, movingItemsTo: nil))
        XCTAssertEqual(store.folders, [.inbox])
    }

    @MainActor
    func testTailscaleStatusLeavesWaitingAndMarksDAAKConnection() {
        let store = MemoryStore()
        XCTAssertEqual(store.syncMessageKey, "sync_waiting")

        store.markSyncReady()
        XCTAssertEqual(store.syncMessageKey, "sync_ready")
        XCTAssertNil(store.lastSync)

        store.markClientConnected()
        XCTAssertEqual(store.syncMessageKey, "sync_client_connected")
        XCTAssertNotNil(store.lastSync)
    }

    func testLegacyItemsDecodeWithoutFolderFields() throws {
        let json = """
        {
          "id":"DFA84E90-1B12-4D58-A557-93275123972C",
          "text":"Eski not",
          "createdAt":100,
          "updatedAt":101,
          "isDone":false,
          "deletedAt":null
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(MemoryItem.self, from: json)
        XCTAssertEqual(item.effectiveFolder, .inbox)
        XCTAssertNil(item.folder)
        XCTAssertNil(item.labels)
    }

    func testLegacyWhatsAppAndMailAreClassified() {
        let whatsApp = MemoryItem(text: "WhatsApp • Deniz: Raporu yollar mısın?")
        var legacyWhatsApp = whatsApp
        legacyWhatsApp.folder = nil
        XCTAssertEqual(legacyWhatsApp.effectiveFolder, .whatsapp)

        var legacyMail = MemoryItem(text: "Mail • Gmail • Ada — Toplantı")
        legacyMail.folder = nil
        XCTAssertEqual(legacyMail.effectiveFolder, .mail)
    }

    func testWhatsAppTaskAppearsInBothSmartViews() {
        let item = MemoryItem(
            text: "WhatsApp • Ada: Bunu yarın yap",
            folder: .whatsapp,
            labels: ["tasks"]
        )
        XCTAssertTrue(item.belongs(to: .whatsapp))
        XCTAssertTrue(item.belongs(to: .tasks))
        XCTAssertFalse(item.belongs(to: .mail))
    }
}
