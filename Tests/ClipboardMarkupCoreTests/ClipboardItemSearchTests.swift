@testable import ClipboardMarkupCore
import XCTest

final class ClipboardItemSearchTests: XCTestCase {
    func testEmptySearchMatches() {
        let item = ClipboardItem(
            kind: .text,
            plainText: "A useful copied note",
            fingerprint: "text:test"
        )

        XCTAssertTrue(item.matchesSearch(""))
        XCTAssertTrue(item.matchesSearch("   "))
    }

    func testSearchMatchesCustomTitle() {
        let item = ClipboardItem(
            kind: .image,
            customTitle: "Launch metrics screenshot",
            imageTranscript: "Q2 weekly report",
            fingerprint: "image:test"
        )

        XCTAssertTrue(item.matchesSearch("metrics"))
    }

    func testSearchMatchesPlainTextContent() {
        let item = ClipboardItem(
            kind: .text,
            plainText: "Monthly licenses ramped to 45 percent",
            fingerprint: "text:test"
        )

        XCTAssertTrue(item.matchesSearch("licenses 45"))
    }

    func testSearchMatchesImageTranscript() {
        let item = ClipboardItem(
            kind: .image,
            imageTranscript: "Activity Score review reached full manager coverage",
            fingerprint: "image:test"
        )

        XCTAssertTrue(item.matchesSearch("manager coverage"))
    }

    func testSearchIsCaseAndDiacriticInsensitive() {
        let item = ClipboardItem(
            kind: .text,
            plainText: "Résumé notes for Launch Review",
            fingerprint: "text:test"
        )

        XCTAssertTrue(item.matchesSearch("resume launch"))
        XCTAssertFalse(item.matchesSearch("weekly"))
    }
}
