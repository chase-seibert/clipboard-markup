@testable import ClipboardMarkupCore
import XCTest

@MainActor
final class LibraryPreferencesTests: XCTestCase {
    func testDefaultsToImagesWithNoSelection() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = LibraryPreferences(userDefaults: userDefaults)

        XCTAssertEqual(preferences.filter, .images)
        XCTAssertNil(preferences.selectedItemID)
    }

    func testFilterAndSelectedItemPersist() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let selectedItemID = UUID()
        let preferences = LibraryPreferences(userDefaults: userDefaults)
        preferences.setFilter(.favorites)
        preferences.setSelectedItemID(selectedItemID)

        let reloaded = LibraryPreferences(userDefaults: userDefaults)

        XCTAssertEqual(reloaded.filter, .favorites)
        XCTAssertEqual(reloaded.selectedItemID, selectedItemID)
    }

    func testClearingSelectedItemRemovesPersistedSelection() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = LibraryPreferences(userDefaults: userDefaults)
        preferences.setSelectedItemID(UUID())
        preferences.setSelectedItemID(nil)

        let reloaded = LibraryPreferences(userDefaults: userDefaults)

        XCTAssertNil(reloaded.selectedItemID)
    }

    func testInvalidStoredFilterFallsBackToImages() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults.set("missing", forKey: "library.filter")

        let preferences = LibraryPreferences(userDefaults: userDefaults)

        XCTAssertEqual(preferences.filter, .images)
    }
}
