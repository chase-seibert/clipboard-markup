@testable import ClipboardMarkupCore
import XCTest

final class ThumbnailFocusTests: XCTestCase {
    func testNormalizedRectClampsToImageBounds() {
        let rect = NormalizedRect(x: 0.9, y: -0.2, width: 0.4, height: 1.4)

        XCTAssertEqual(rect.x, 0.6)
        XCTAssertEqual(rect.y, 0)
        XCTAssertEqual(rect.width, 0.4)
        XCTAssertEqual(rect.height, 1)
    }

    func testRecognitionResultNormalizesTranscript() {
        let result = ImageTextRecognitionResult(
            transcript: "  Weekly\n\nreport   notes  ",
            thumbnailFocusRect: .defaultThumbnailFocus
        )

        XCTAssertEqual(result.transcript, "Weekly report notes")
        XCTAssertEqual(result.thumbnailFocusRect, .defaultThumbnailFocus)
    }

    func testClipboardItemDecodesWithoutThumbnailFocusRect() throws {
        let data = Data(
            """
            {
              "createdAt": "2026-06-30T12:00:00Z",
              "fingerprint": "image:test",
              "id": "11111111-1111-1111-1111-111111111111",
              "imageHeight": 440,
              "imageTranscript": "Weekly report",
              "imageWidth": 300,
              "isSaved": false,
              "kind": "image",
              "markups": [],
              "originalImageFilename": "original.png",
              "updatedAt": "2026-06-30T12:00:00Z"
            }
            """.utf8
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let item = try decoder.decode(ClipboardItem.self, from: data)

        XCTAssertEqual(item.title, "Weekly report")
        XCTAssertNil(item.thumbnailFocusRect)
    }
}
