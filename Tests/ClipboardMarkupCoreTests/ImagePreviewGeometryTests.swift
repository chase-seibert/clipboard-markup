import CoreGraphics
@testable import ClipboardMarkupCore
import XCTest

final class ImagePreviewGeometryTests: XCTestCase {
    func testFittedImageRectDoesNotUpscaleBeyondNativeSize() {
        let rect = fittedImageRect(
            imageSize: CGSize(width: 640, height: 480),
            containerSize: CGSize(width: 2000, height: 1600)
        )

        XCTAssertEqual(rect.width, 640, accuracy: 0.001)
        XCTAssertEqual(rect.height, 480, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 1000, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 800, accuracy: 0.001)
    }

    func testFittedImageRectScalesDownToFitContainer() {
        let rect = fittedImageRect(
            imageSize: CGSize(width: 640, height: 480),
            containerSize: CGSize(width: 320, height: 320)
        )

        XCTAssertEqual(rect.width, 320, accuracy: 0.001)
        XCTAssertEqual(rect.height, 240, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 160, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 160, accuracy: 0.001)
    }
}
