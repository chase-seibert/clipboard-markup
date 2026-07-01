import AppKit
@testable import ClipboardMarkupCore
import XCTest

final class MenuBarThumbnailRendererTests: XCTestCase {
    func testThumbnailUsesRequestedSizeAndKeepsColorImage() {
        let image = NSImage(size: NSSize(width: 160, height: 90))
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 160, height: 90).fill()
        image.unlockFocus()

        let thumbnail = MenuBarThumbnailRenderer.thumbnail(
            for: image,
            size: NSSize(width: 18, height: 18)
        )

        XCTAssertEqual(thumbnail?.size.width, 18)
        XCTAssertEqual(thumbnail?.size.height, 18)
        XCTAssertEqual(thumbnail?.isTemplate, false)
    }

    func testAspectFillSourceRectCropsWideImagesFromCenter() {
        let rect = MenuBarThumbnailRenderer.aspectFillSourceRect(
            imageSize: NSSize(width: 200, height: 100),
            targetSize: NSSize(width: 20, height: 20)
        )

        XCTAssertEqual(rect.width, 100, accuracy: 0.001)
        XCTAssertEqual(rect.height, 100, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 100, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 50, accuracy: 0.001)
    }
}
