@testable import ClipboardMarkupCore
import XCTest

final class ClipboardItemTitleTests: XCTestCase {
    func testImageTitleFallsBackToDimensions() {
        let item = ClipboardItem(
            kind: .image,
            imageWidth: 300,
            imageHeight: 440,
            fingerprint: "image:test"
        )

        XCTAssertEqual(item.title, "Image 300 x 440")
    }

    func testImageTitleUsesTranscriptWhenAvailable() {
        let item = ClipboardItem(
            kind: .image,
            imageWidth: 300,
            imageHeight: 440,
            imageTranscript: "  Activity Score review reached full manager coverage\nand moved toward weekly follow-up  ",
            fingerprint: "image:test"
        )

        XCTAssertEqual(item.title, "Activity Score review reached full manager coverage and moved toward weekly")
    }

    func testCustomTitleOverridesTranscript() {
        let item = ClipboardItem(
            kind: .image,
            customTitle: "Revenue notes",
            imageTranscript: "Activity Score review reached full manager coverage",
            fingerprint: "image:test"
        )

        XCTAssertEqual(item.title, "Revenue notes")
    }
}
