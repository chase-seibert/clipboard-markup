import UniformTypeIdentifiers
@testable import ClipboardMarkupCore
import XCTest

final class ClipboardTransferPlannerTests: XCTestCase {
    func testRichTextCanExportAsRTFAndPlainText() {
        let item = ClipboardItem(
            kind: .text,
            plainText: "hello",
            richTextFilename: "hello.rtf",
            customTitle: "Meeting Notes",
            fingerprint: "text:hello"
        )

        XCTAssertEqual(ClipboardTransferPlanner.availableFormats(for: item), [.richText, .plainText])

        let rtfPlan = ClipboardTransferPlanner.exportPlan(for: item, format: .richText)
        XCTAssertEqual(rtfPlan.suggestedFilename, "Meeting Notes.rtf")
        XCTAssertEqual(rtfPlan.contentType, .rtf)

        let plainPlan = ClipboardTransferPlanner.exportPlan(for: item, format: .plainText)
        XCTAssertEqual(plainPlan.suggestedFilename, "Meeting Notes.txt")
        XCTAssertEqual(plainPlan.contentType, .plainText)
    }

    func testImageCanExportPreferredAndOriginalPNG() {
        let item = ClipboardItem(
            kind: .image,
            originalImageFilename: "original.png",
            markedImageFilename: "marked.png",
            customTitle: "Screenshot: Weird/File",
            fingerprint: "image:test"
        )

        XCTAssertEqual(ClipboardTransferPlanner.availableFormats(for: item), [.preferredImage, .originalImage])

        let preferredPlan = ClipboardTransferPlanner.exportPlan(for: item, format: .preferredImage)
        XCTAssertEqual(preferredPlan.suggestedFilename, "Screenshot Weird File.png")
        XCTAssertEqual(preferredPlan.contentType, .png)

        let originalPlan = ClipboardTransferPlanner.exportPlan(for: item, format: .originalImage)
        XCTAssertEqual(originalPlan.suggestedFilename, "Screenshot Weird File-original.png")
        XCTAssertEqual(originalPlan.contentType, .png)
    }

    func testDeletedItemHasNoExportFormats() {
        let item = ClipboardItem(
            deletedAt: Date(),
            kind: .text,
            plainText: "deleted",
            fingerprint: "text:deleted"
        )

        XCTAssertEqual(ClipboardTransferPlanner.availableFormats(for: item), [])
        XCTAssertNil(ClipboardTransferPlanner.defaultFormat(for: item))
    }
}
