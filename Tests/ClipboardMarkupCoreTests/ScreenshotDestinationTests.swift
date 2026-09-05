@testable import ClipboardMarkupCore
import XCTest

final class ScreenshotDestinationTests: XCTestCase {
    func testMissingPreferencesUseDefaultFileDestination() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertEqual(ScreenshotDestination.read(preferencesURL: url), .defaultFile)
    }

    func testDestinationHintsAndUnknownValues() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let cases: [([String: Any], ScreenshotDestination)] = [
            ([:], .defaultFile),
            (["location": "/tmp/screenshots"], .file),
            (["target": "file"], .file),
            (["target": "clipboard", "location": "/tmp/screenshots"], .clipboard),
            (["target": "preview"], .other),
            (["target": "new-macos-value"], .unknown),
            (["target": 42], .unknown)
        ]
        for (preferences, expected) in cases {
            let data = try PropertyListSerialization.data(fromPropertyList: preferences, format: .binary, options: 0)
            try data.write(to: url)
            XCTAssertEqual(ScreenshotDestination.read(preferencesURL: url), expected)
        }
    }

    func testUnreadablePreferencesAreNotReportedAsDesktop() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("invalid plist".utf8).write(to: url)
        XCTAssertEqual(ScreenshotDestination.read(preferencesURL: url), .unknown)
    }
}
