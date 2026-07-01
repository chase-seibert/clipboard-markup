@testable import ClipboardMarkupCore
import XCTest

@MainActor
final class StorageLocationPreferencesTests: XCTestCase {
    func testDefaultsToApplicationSupportStorage() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let preferences = StorageLocationPreferences(userDefaults: userDefaults)

        XCTAssertTrue(preferences.isUsingDefaultLocation)
        XCTAssertEqual(preferences.rootURL.path, StorageLocationPreferences.defaultRootURL().path)
    }

    func testCustomRootPersistsAndDefaultResetClearsOverride() {
        let suiteName = "ClipboardMarkupTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite.")
        }
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let customRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMarkupCustom-\(UUID().uuidString)", isDirectory: true)
        let preferences = StorageLocationPreferences(userDefaults: userDefaults)

        preferences.setRootURL(customRootURL)
        XCTAssertFalse(preferences.isUsingDefaultLocation)
        XCTAssertEqual(preferences.rootURL.path, customRootURL.standardizedFileURL.path)

        let reloaded = StorageLocationPreferences(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.rootURL.path, customRootURL.standardizedFileURL.path)

        reloaded.resetToDefault()
        XCTAssertTrue(reloaded.isUsingDefaultLocation)
        XCTAssertEqual(reloaded.rootURL.path, StorageLocationPreferences.defaultRootURL().path)
    }

    func testRecommendedLocationsIncludeCloudProviderFolders() {
        let presets = StorageLocationPreferences.recommendedLocations()

        XCTAssertEqual(presets.map(\.id), [
            .applicationSupport,
            .iCloudDrive,
            .dropbox,
            .googleDrive
        ])
        XCTAssertTrue(presets.allSatisfy { $0.url.lastPathComponent == "ClipboardMarkup" })
    }

    func testDropboxTeamsLocationPrefersMemberFolder() throws {
        let homeURL = temporaryHomeURL()
        defer {
            try? FileManager.default.removeItem(at: homeURL)
        }

        let teamRootURL = homeURL
            .appendingPathComponent("Library/CloudStorage/Dropbox-Dropbox", isDirectory: true)
        let teamMemberURL = teamRootURL
            .appendingPathComponent("Chase Seibert", isDirectory: true)
        let personalURL = homeURL
            .appendingPathComponent("Library/CloudStorage/Dropbox-Personal", isDirectory: true)
        try FileManager.default.createDirectory(at: teamRootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: personalURL, withIntermediateDirectories: true)

        let dropboxURL = StorageLocationPreferences.dropboxURL(
            fileManager: .default,
            homeDirectoryURL: homeURL,
            memberNameCandidates: ["Chase Seibert"]
        )

        XCTAssertEqual(
            canonicalPath(dropboxURL),
            canonicalPath(teamMemberURL
                .appendingPathComponent("ClipboardMarkup", isDirectory: true)
            )
        )
    }

    func testDropboxPersonalLocationUsesTopLevelDropboxRoot() throws {
        let homeURL = temporaryHomeURL()
        defer {
            try? FileManager.default.removeItem(at: homeURL)
        }

        let personalURL = homeURL
            .appendingPathComponent("Library/CloudStorage/Dropbox-Personal", isDirectory: true)
        try FileManager.default.createDirectory(at: personalURL, withIntermediateDirectories: true)

        let dropboxURL = StorageLocationPreferences.dropboxURL(
            fileManager: .default,
            homeDirectoryURL: homeURL,
            memberNameCandidates: ["Chase Seibert"]
        )

        XCTAssertEqual(
            canonicalPath(dropboxURL),
            canonicalPath(personalURL
                .appendingPathComponent("ClipboardMarkup", isDirectory: true)
            )
        )
    }

    private func temporaryHomeURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMarkupHome-\(UUID().uuidString)", isDirectory: true)
    }

    private func canonicalPath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: "/private/var/", with: "/var/")
    }
}
