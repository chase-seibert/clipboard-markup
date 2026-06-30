@testable import ClipboardMarkupCore
import XCTest

@MainActor
final class ShortcutPreferencesTests: XCTestCase {
    func testDefaultShortcutIsControlOptionC() {
        XCTAssertEqual(KeyboardShortcutPreference.defaultShortcut.displayLabel, "⌃⌥C")
    }

    func testShortcutPreferencePersistsKeyCodeModifiersAndDisplayLabel() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = ShortcutPreferences(userDefaults: userDefaults)
        let shortcut = KeyboardShortcutPreference.presets[1]

        preferences.setShortcut(shortcut)

        let reloaded = ShortcutPreferences(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.shortcut, shortcut)
    }
}
