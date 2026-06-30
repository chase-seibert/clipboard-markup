import AppKit
@testable import ClipboardMarkupCore
import XCTest

final class PasteboardReaderTests: XCTestCase {
    func testCapturesPlainTextFromPasteboard() {
        let pasteboard = makePasteboard()
        pasteboard.setString("hello clipboard", forType: .string)

        guard case let .text(plainText, richRTF, _) = PasteboardReader.capture(from: pasteboard) else {
            return XCTFail("Expected text capture.")
        }

        XCTAssertEqual(plainText, "hello clipboard")
        XCTAssertNil(richRTF)
    }

    func testCapturesRichTextFromPasteboard() throws {
        let pasteboard = makePasteboard()
        let attributed = NSAttributedString(
            string: "rich clipboard",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 18)]
        )
        let range = NSRange(location: 0, length: attributed.length)
        let data = try attributed.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])

        pasteboard.setData(data, forType: .rtf)
        pasteboard.setString(attributed.string, forType: .string)

        guard case let .text(plainText, richRTF, _) = PasteboardReader.capture(from: pasteboard) else {
            return XCTFail("Expected rich text capture.")
        }

        XCTAssertEqual(plainText, "rich clipboard")
        XCTAssertNotNil(richRTF)
    }

    func testCapturesImageFromPasteboard() {
        let pasteboard = makePasteboard()
        let image = NSImage(size: CGSize(width: 24, height: 24))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 24, height: 24)).fill()
        image.unlockFocus()

        pasteboard.writeObjects([image])

        guard case let .image(capturedImage, _) = PasteboardReader.capture(from: pasteboard) else {
            return XCTFail("Expected image capture.")
        }

        XCTAssertEqual(capturedImage.size.width, 24)
        XCTAssertEqual(capturedImage.size.height, 24)
    }

    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipboardMarkupTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }
}
