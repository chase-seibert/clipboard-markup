import AppKit
@testable import ClipboardMarkupCore
import XCTest

@MainActor
final class ClipboardStoreTests: XCTestCase {
    func testClearHistoryClearsItemsPersistsEmptyHistoryAndLeavesPasteboardAlone() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMarkupTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let storage = ClipboardStorage(rootURL: rootURL)
        let itemID = UUID()
        let richTextFilename = try storage.saveRichText(Data("rich".utf8), itemID: itemID)
        try storage.saveItems([
            ClipboardItem(
                id: itemID,
                kind: .text,
                plainText: "Copied secret-free text",
                richTextFilename: richTextFilename,
                isSaved: true,
                fingerprint: "text:test"
            )
        ])

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipboardMarkupTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("current system clipboard", forType: .string)

        let store = ClipboardStore(
            storage: storage,
            monitor: PasteboardMonitor(pasteboard: pasteboard)
        )

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(pasteboard.string(forType: .string), "current system clipboard")

        XCTAssertTrue(store.clearHistory())

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(store.lastError)
        XCTAssertEqual(try storage.loadItems(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(filename: richTextFilename).path))
        XCTAssertEqual(pasteboard.string(forType: .string), "current system clipboard")
    }
}
