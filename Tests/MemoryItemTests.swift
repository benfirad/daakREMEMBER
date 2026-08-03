import Foundation
import XCTest
@testable import AklimaGeldi

final class MemoryItemTests: XCTestCase {
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
