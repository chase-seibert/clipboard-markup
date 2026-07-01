import AppKit
@testable import ClipboardMarkupCore
import XCTest

final class ClipboardStorageTests: XCTestCase {
    func testDeleteMediaRemovesAssociatedFiles() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMarkupTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let storage = ClipboardStorage(rootURL: rootURL)
        let itemID = UUID()
        let richTextFilename = try storage.saveRichText(Data("rich".utf8), itemID: itemID)
        let originalFilename = try storage.saveImage(testImage(), itemID: itemID, variant: "original")
        let markedFilename = try storage.saveImage(testImage(), itemID: itemID, variant: "marked")
        let item = ClipboardItem(
            id: itemID,
            kind: .image,
            richTextFilename: richTextFilename,
            originalImageFilename: originalFilename,
            markedImageFilename: markedFilename,
            fingerprint: "image:test"
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(filename: richTextFilename).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(filename: originalFilename).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(filename: markedFilename).path))

        try storage.deleteMedia(for: item)

        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(filename: richTextFilename).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(filename: originalFilename).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(filename: markedFilename).path))
    }

    func testPurgeExpiredDeletedItemsRemovesOnlyExpiredDeletedMedia() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMarkupTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let storage = ClipboardStorage(rootURL: rootURL)
        let now = Date()
        let expiredID = UUID()
        let recentID = UUID()
        let activeID = UUID()
        let expiredFilename = try storage.saveImage(testImage(), itemID: expiredID, variant: "original")
        let recentFilename = try storage.saveImage(testImage(), itemID: recentID, variant: "original")
        let activeFilename = try storage.saveImage(testImage(), itemID: activeID, variant: "original")
        let expiredDeletedItem = ClipboardItem(
            id: expiredID,
            deletedAt: now.addingTimeInterval(-ClipboardItem.deletedItemRetentionInterval - 60),
            kind: .image,
            originalImageFilename: expiredFilename,
            fingerprint: "image:expired"
        )
        let recentDeletedItem = ClipboardItem(
            id: recentID,
            deletedAt: now.addingTimeInterval(-ClipboardItem.deletedItemRetentionInterval + 60),
            kind: .image,
            originalImageFilename: recentFilename,
            fingerprint: "image:recent"
        )
        let activeItem = ClipboardItem(
            id: activeID,
            kind: .image,
            originalImageFilename: activeFilename,
            fingerprint: "image:active"
        )

        let retainedItems = try storage.purgeExpiredDeletedItems(
            from: [expiredDeletedItem, recentDeletedItem, activeItem],
            now: now
        )

        XCTAssertEqual(retainedItems.map(\.id), [recentID, activeID])
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(filename: expiredFilename).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(filename: recentFilename).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(filename: activeFilename).path))
    }

    func testEnsureAgentGuideWritesGuideWithAbsolutePaths() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMarkupTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let storage = ClipboardStorage(rootURL: rootURL)

        try storage.ensureAgentGuide()

        let guide = try String(contentsOf: storage.agentGuideURL)
        XCTAssertTrue(guide.contains(storage.rootURL.path))
        XCTAssertTrue(guide.contains(storage.manifestURL.path))
        XCTAssertTrue(guide.contains(storage.mediaURL.path))
        XCTAssertTrue(guide.contains(storage.agentGuideURL.path))
        XCTAssertTrue(guide.contains("markedImageFilename"))
        XCTAssertTrue(guide.contains("originalImageFilename"))
        XCTAssertTrue(storage.agentPromptSnippet.contains(storage.agentGuideURL.path))
        XCTAssertTrue(storage.agentPromptSnippet.contains("type and date range"))
    }

    func testClearHistoryRemovesMediaWritesEmptyManifestAndPreservesAgentGuide() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMarkupTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let storage = ClipboardStorage(rootURL: rootURL)
        let itemID = UUID()
        let richTextFilename = try storage.saveRichText(Data("rich".utf8), itemID: itemID)
        let originalFilename = try storage.saveImage(testImage(), itemID: itemID, variant: "original")
        let item = ClipboardItem(
            id: itemID,
            kind: .image,
            richTextFilename: richTextFilename,
            originalImageFilename: originalFilename,
            fingerprint: "image:test"
        )
        try storage.saveItems([item])

        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(filename: richTextFilename).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(filename: originalFilename).path))

        try storage.clearHistory()

        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.mediaURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.manifestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.agentGuideURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(filename: richTextFilename).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(filename: originalFilename).path))
        XCTAssertEqual(try storage.loadItems(), [])

        let guide = try String(contentsOf: storage.agentGuideURL)
        XCTAssertTrue(guide.contains(storage.agentGuideURL.path))
    }

    private func testImage() -> NSImage {
        let image = NSImage(size: CGSize(width: 12, height: 12))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 12, height: 12)).fill()
        image.unlockFocus()
        return image
    }
}
