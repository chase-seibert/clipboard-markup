import AppKit
@testable import ClipboardMarkupCore
import XCTest

final class PasteboardReaderTests: XCTestCase {
    func testCapturesPNGAndTIFFPayloadsWithoutAppKitWriter() throws {
        let image = makeImage()
        for (type, data) in [(NSPasteboard.PasteboardType.png, image.pngData), (.tiff, image.tiffRepresentation)] {
            let pasteboard = makePasteboard()
            defer { pasteboard.releaseGlobally() }
            XCTAssertTrue(pasteboard.setData(try XCTUnwrap(data), forType: type))
            guard case let .image(captured, _) = PasteboardReader.capture(from: pasteboard) else {
                return XCTFail("Expected image capture for \(type.rawValue)")
            }
            XCTAssertNotNil(captured.pngData)
        }
    }

    func testCapturesImageFileCopiedFromFinder() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try XCTUnwrap(makeImage().pngData).write(to: fileURL)
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(pasteboard.writeObjects([fileURL as NSURL]))

        guard case .image = PasteboardReader.capture(from: pasteboard) else {
            return XCTFail("Expected image capture from file URL")
        }
    }

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

    func testImageWriterStoresAlternateFormatsOnOnePasteboardItem() {
        let pasteboard = makePasteboard()
        let image = makeImage()

        XCTAssertTrue(PasteboardWriter.writeImage(image, to: pasteboard))
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1)
        XCTAssertEqual(
            Set(pasteboard.pasteboardItems?.first?.types ?? []),
            Set([NSPasteboard.PasteboardType.png, NSPasteboard.PasteboardType.tiff])
        )
    }

    func testImageWriterReplacesPreviousContentsWithOneItem() {
        let pasteboard = makePasteboard()
        pasteboard.writeObjects([makeImage(), makeImage()])

        XCTAssertTrue(PasteboardWriter.writeImage(makeImage(), to: pasteboard))
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1)
    }

    func testSkipsConcealedPasteboardContent() {
        let pasteboard = makePasteboard()
        pasteboard.setString("super-secret-password", forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))

        XCTAssertNil(PasteboardReader.capture(from: pasteboard))
    }

    func testSkipsTransientPasteboardContent() {
        let pasteboard = makePasteboard()
        pasteboard.setString("one-time-code", forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        XCTAssertNil(PasteboardReader.capture(from: pasteboard))
    }

    func testSkipsOnePasswordPasteboardMarker() {
        let pasteboard = makePasteboard()
        pasteboard.setString("super-secret-password", forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("com.agilebits.onepassword"))

        XCTAssertNil(PasteboardReader.capture(from: pasteboard))
    }

    func testSkipsKnownPasswordManagerSource() {
        let pasteboard = makePasteboard()
        pasteboard.setString("super-secret-password", forType: .string)
        pasteboard.setString("com.1password.1password", forType: NSPasteboard.PasteboardType("org.nspasteboard.source"))

        XCTAssertNil(PasteboardReader.capture(from: pasteboard))
    }

    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipboardMarkupTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }

    private func makeImage() -> NSImage {
        let image = NSImage(size: CGSize(width: 24, height: 24))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 24, height: 24)).fill()
        image.unlockFocus()
        return image
    }
}
