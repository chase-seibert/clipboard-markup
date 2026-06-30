@testable import ClipboardMarkupCore
import XCTest

final class MenuBarTitleFormatterTests: XCTestCase {
    func testLongTextTitlesAreCappedForMenuBar() {
        let item = ClipboardItem(
            kind: .text,
            plainText: "This is a very long clipboard item that should not stretch the menu bar",
            fingerprint: "text:test"
        )

        let title = MenuBarTitleFormatter.title(for: item)

        XCTAssertLessThanOrEqual(title.count, 30)
        XCTAssertTrue(title.hasSuffix("..."))
    }

    func testImagesUseItemTitle() {
        let item = ClipboardItem(
            kind: .image,
            originalImageFilename: "original.png",
            markedImageFilename: "marked.png",
            customTitle: "Quarterly growth dashboard",
            fingerprint: "image:test"
        )

        XCTAssertEqual(MenuBarTitleFormatter.title(for: item), "Quarterly growth dashboard")
    }
}
