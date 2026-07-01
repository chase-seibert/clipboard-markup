@testable import ClipboardMarkupCore
import XCTest

final class ClipboardCommandStateTests: XCTestCase {
    func testNoSelectionDisablesClipCommands() {
        let state = ClipboardCommandState(item: nil)

        XCTAssertFalse(state.canCopy)
        XCTAssertFalse(state.canMarkup)
        XCTAssertFalse(state.canRename)
        XCTAssertFalse(state.canDelete)
        XCTAssertFalse(state.canRestore)
        XCTAssertFalse(state.canExport)
    }

    func testTextSelectionEnablesTextCommands() {
        let item = ClipboardItem(
            kind: .text,
            plainText: "hello",
            richTextFilename: "rich.rtf",
            fingerprint: "text:hello"
        )

        let state = ClipboardCommandState(item: item)

        XCTAssertTrue(state.canCopy)
        XCTAssertTrue(state.canCopyPlainText)
        XCTAssertFalse(state.canCopyOriginalImage)
        XCTAssertFalse(state.canMarkup)
        XCTAssertTrue(state.canRename)
        XCTAssertTrue(state.canToggleFavorite)
        XCTAssertTrue(state.canDelete)
        XCTAssertTrue(state.canExport)
    }

    func testImageSelectionEnablesImageCommands() {
        let item = ClipboardItem(
            kind: .image,
            originalImageFilename: "image.png",
            fingerprint: "image:test"
        )

        let state = ClipboardCommandState(item: item)

        XCTAssertTrue(state.canCopy)
        XCTAssertFalse(state.canCopyPlainText)
        XCTAssertTrue(state.canCopyOriginalImage)
        XCTAssertTrue(state.canMarkup)
        XCTAssertTrue(state.canQuickLook)
        XCTAssertTrue(state.canExport)
    }

    func testDeletedSelectionOnlyEnablesRenameAndRestore() {
        let item = ClipboardItem(
            deletedAt: Date(),
            kind: .image,
            originalImageFilename: "image.png",
            fingerprint: "image:test"
        )

        let state = ClipboardCommandState(item: item)

        XCTAssertFalse(state.canCopy)
        XCTAssertFalse(state.canMarkup)
        XCTAssertTrue(state.canRename)
        XCTAssertFalse(state.canDelete)
        XCTAssertTrue(state.canRestore)
        XCTAssertFalse(state.canExport)
    }
}
