import AppKit
@testable import ClipboardMarkupCore
import XCTest

@MainActor
final class ClipboardStoreTests: XCTestCase {
    func testMonitorCapturesPNGAndPersistsReloadableImage() async throws {
        let rootURL = temporaryRootURL()
        let storage = ClipboardStorage(rootURL: rootURL)
        let pasteboard = testPasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard)
        let store = ClipboardStore(storage: storage, monitor: monitor)
        defer {
            monitor.stop()
            pasteboard.releaseGlobally()
            try? FileManager.default.removeItem(at: rootURL)
        }
        monitor.start()
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setData(try XCTUnwrap(testImage().pngData), forType: .png))
        // Exercise the real timer, then verify decoding and persistence together.
        for _ in 0..<40 where store.items.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
        }

        XCTAssertNil(store.lastError)
        let item = try XCTUnwrap(store.items.first)
        XCTAssertEqual(item.kind, .image)
        let filename = try XCTUnwrap(item.originalImageFilename)
        XCTAssertNotNil(storage.image(filename: filename))
        XCTAssertEqual(try storage.loadItems().first?.id, item.id)
    }

    func testUndoableRenameFavoriteDeleteRestoreAndMarkupReplacement() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let storage = ClipboardStorage(rootURL: rootURL)
        let textID = UUID()
        let imageID = UUID()
        let originalFilename = try storage.saveImage(testImage(), itemID: imageID, variant: "original")
        try storage.saveItems([
            ClipboardItem(
                id: textID,
                kind: .text,
                plainText: "Original text",
                fingerprint: "text:original"
            ),
            ClipboardItem(
                id: imageID,
                kind: .image,
                originalImageFilename: originalFilename,
                fingerprint: "image:original"
            )
        ])

        let store = ClipboardStore(
            storage: storage,
            monitor: PasteboardMonitor(pasteboard: testPasteboard())
        )
        let undoManager = UndoManager()

        store.rename(itemID: textID, title: "Renamed", undoManager: undoManager)
        XCTAssertEqual(store.item(id: textID)?.title, "Renamed")
        undoManager.undo()
        XCTAssertEqual(store.item(id: textID)?.title, "Original text")
        undoManager.redo()
        XCTAssertEqual(store.item(id: textID)?.title, "Renamed")

        store.toggleSaved(itemID: textID, undoManager: undoManager)
        XCTAssertEqual(store.item(id: textID)?.isSaved, true)
        undoManager.undo()
        XCTAssertEqual(store.item(id: textID)?.isSaved, false)

        store.delete(itemID: textID, undoManager: undoManager)
        XCTAssertEqual(store.item(id: textID)?.isDeleted, true)
        undoManager.undo()
        XCTAssertEqual(store.item(id: textID)?.isDeleted, false)
        undoManager.redo()
        XCTAssertEqual(store.item(id: textID)?.isDeleted, true)

        store.restore(itemID: textID, undoManager: undoManager)
        XCTAssertEqual(store.item(id: textID)?.isDeleted, false)
        undoManager.undo()
        XCTAssertEqual(store.item(id: textID)?.isDeleted, true)

        let markup = MarkupElement(
            kind: .rectangle,
            start: NormalizedPoint(x: 0.1, y: 0.1),
            end: NormalizedPoint(x: 0.8, y: 0.8)
        )
        store.updateMarkups(itemID: imageID, elements: [markup], undoManager: undoManager)
        XCTAssertEqual(store.item(id: imageID)?.markups, [markup])
        XCTAssertNotNil(store.item(id: imageID)?.markedImageFilename)
        undoManager.undo()
        XCTAssertEqual(store.item(id: imageID)?.markups, [])
        XCTAssertNil(store.item(id: imageID)?.markedImageFilename)
    }

    func testClearHistoryClearsItemsPersistsEmptyHistoryAndLeavesPasteboardAlone() throws {
        let rootURL = temporaryRootURL()
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

    func testMigrateStorageCopiesDataAndSwitchesStoreToDestination() throws {
        let sourceRootURL = temporaryRootURL()
        let destinationRootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: sourceRootURL)
            try? FileManager.default.removeItem(at: destinationRootURL)
        }

        let sourceStorage = ClipboardStorage(rootURL: sourceRootURL)
        let itemID = UUID()
        let richTextFilename = try sourceStorage.saveRichText(Data("rich".utf8), itemID: itemID)
        let item = ClipboardItem(
            id: itemID,
            kind: .text,
            plainText: "Migrated clip",
            richTextFilename: richTextFilename,
            fingerprint: "text:migrated"
        )
        try sourceStorage.saveItems([item])

        let store = ClipboardStore(
            storage: sourceStorage,
            monitor: PasteboardMonitor(pasteboard: testPasteboard())
        )

        XCTAssertTrue(store.migrateStorage(to: destinationRootURL))

        let destinationStorage = ClipboardStorage(rootURL: destinationRootURL)
        XCTAssertEqual(store.dataDirectoryURL.path, destinationRootURL.standardizedFileURL.path)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.id, item.id)
        XCTAssertEqual(store.items.first?.plainText, item.plainText)

        let loadedItems = try destinationStorage.loadItems()
        XCTAssertEqual(loadedItems.count, 1)
        XCTAssertEqual(loadedItems.first?.id, item.id)
        XCTAssertEqual(loadedItems.first?.plainText, item.plainText)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationStorage.url(filename: richTextFilename).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationStorage.agentGuideURL.path))
    }

    func testStoreActionsRecordAnalyticsEvents() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let storage = ClipboardStorage(rootURL: rootURL)
        let itemID = UUID()
        try storage.saveItems([
            ClipboardItem(
                id: itemID,
                kind: .text,
                plainText: "Analytics-safe text",
                fingerprint: "text:analytics"
            )
        ])

        let store = ClipboardStore(
            storage: storage,
            monitor: PasteboardMonitor(pasteboard: testPasteboard())
        )
        let recorder = AnalyticsSpy()
        store.analyticsRecorder = recorder

        store.rename(itemID: itemID, title: "Renamed for analytics")
        store.toggleSaved(itemID: itemID)
        store.delete(itemID: itemID)

        XCTAssertEqual(
            recorder.events,
            [
                .clipAction(.renamed),
                .clipAction(.favoriteAdded),
                .clipAction(.deleted)
            ]
        )
    }

    private func temporaryRootURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMarkupTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func testPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("ClipboardMarkupTests.\(UUID().uuidString)"))
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

@MainActor
private final class AnalyticsSpy: AnalyticsRecording {
    var events: [AnalyticsEventKind] = []

    func record(_ kind: AnalyticsEventKind) {
        events.append(kind)
    }
}
