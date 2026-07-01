@testable import ClipboardMarkupCore
import XCTest

@MainActor
final class AppearancePreferencesTests: XCTestCase {
    func testFontScaleDefaultsToOneHundredPercent() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = AppearancePreferences(userDefaults: userDefaults)

        XCTAssertEqual(preferences.fontScale, 1.0)
        XCTAssertEqual(preferences.percentageLabel, "100%")
    }

    func testFontScalePersistsAndClamps() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = AppearancePreferences(userDefaults: userDefaults)

        preferences.setFontScale(9.0)
        XCTAssertEqual(preferences.fontScale, AppearancePreferences.maximumFontScale)

        preferences.setFontScale(1.2)
        let reloaded = AppearancePreferences(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.fontScale, 1.2)

        reloaded.setFontScale(0.1)
        XCTAssertEqual(reloaded.fontScale, AppearancePreferences.minimumFontScale)
    }

    func testThumbnailSizePersistsAndClamps() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = AppearancePreferences(userDefaults: userDefaults)

        XCTAssertEqual(preferences.thumbnailSize, AppearancePreferences.defaultThumbnailSize)
        XCTAssertEqual(preferences.thumbnailSizeLabel, "64 pt")

        preferences.setThumbnailSize(400)
        XCTAssertEqual(preferences.thumbnailSize, AppearancePreferences.maximumThumbnailSize)
        XCTAssertEqual(preferences.thumbnailSize, 300)

        preferences.setThumbnailSize(72)
        let reloaded = AppearancePreferences(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.thumbnailSize, 72)

        reloaded.setThumbnailSize(10)
        XCTAssertEqual(reloaded.thumbnailSize, AppearancePreferences.minimumThumbnailSize)
    }

    func testColorSchemePreferenceDefaultsPersistsAndFallsBackToSystem() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = AppearancePreferences(userDefaults: userDefaults)
        XCTAssertEqual(preferences.colorSchemePreference, .system)

        preferences.setColorSchemePreference(.dark)
        let reloaded = AppearancePreferences(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.colorSchemePreference, .dark)

        userDefaults.set("midnight", forKey: "appearance.colorSchemePreference")
        let invalidReload = AppearancePreferences(userDefaults: userDefaults)
        XCTAssertEqual(invalidReload.colorSchemePreference, .system)
    }
}
