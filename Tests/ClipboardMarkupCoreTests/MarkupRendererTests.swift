import AppKit
@testable import ClipboardMarkupCore
import XCTest

final class MarkupRendererTests: XCTestCase {
    func testNormalizedPointClampsToImageBounds() {
        let point = NormalizedPoint(x: 1.4, y: -0.2)

        XCTAssertEqual(point.x, 1)
        XCTAssertEqual(point.y, 0)
    }

    func testRendererPreservesOriginalImageSize() {
        let image = NSImage(size: CGSize(width: 200, height: 100))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 200, height: 100)).fill()
        image.unlockFocus()

        let element = MarkupElement(
            kind: .rectangle,
            start: NormalizedPoint(x: 0.1, y: 0.2),
            end: NormalizedPoint(x: 0.8, y: 0.7),
            colorHex: "#FF3B30",
            lineWidth: 6
        )

        let rendered = MarkupRenderer.render(original: image, elements: [element])

        XCTAssertEqual(rendered.size.width, 200)
        XCTAssertEqual(rendered.size.height, 100)
        XCTAssertNotNil(rendered.pngData)
    }
}
