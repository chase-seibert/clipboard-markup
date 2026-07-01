@testable import ClipboardMarkupCore
import Combine
import XCTest

@MainActor
final class AnalyticsRecorderTests: XCTestCase {
    func testPreferencesDefaultToEnabledAndPersistInstallID() {
        let userDefaults = isolatedUserDefaults()
        let preferences = AnalyticsPreferences(userDefaults: userDefaults)

        XCTAssertTrue(preferences.isSharingEnabled)
        XCTAssertFalse(preferences.installID.isEmpty)

        let reloaded = AnalyticsPreferences(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.installID, preferences.installID)
        XCTAssertTrue(reloaded.isSharingEnabled)
    }

    func testRecorderDoesNotEnqueueWhenDisabled() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let preferences = AnalyticsPreferences(userDefaults: isolatedUserDefaults())
        preferences.setSharingEnabled(false)
        let queue = AnalyticsQueue(rootURL: rootURL)
        let recorder = AnalyticsRecorder(
            preferences: preferences,
            configurationResult: .success(try testConfiguration()),
            queue: queue,
            uploader: AnalyticsUploader(client: StubAnalyticsHTTPClient())
        )

        recorder.record(.appOpen)

        XCTAssertEqual(queue.eventCount, 0)
        XCTAssertEqual(recorder.status, .disabled)
    }

    func testRecorderEnqueuesPrivacySafeEventWhenEnabled() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let preferences = AnalyticsPreferences(userDefaults: isolatedUserDefaults())
        let queue = AnalyticsQueue(rootURL: rootURL)
        let recorder = AnalyticsRecorder(
            preferences: preferences,
            configurationResult: .success(try testConfiguration()),
            queue: queue,
            uploader: AnalyticsUploader(client: StubAnalyticsHTTPClient())
        )

        recorder.record(.clipAction(.copy))

        XCTAssertEqual(queue.eventCount, 1)
        XCTAssertEqual(recorder.status, .enabled)
    }

    func testRecorderDoesNotEnqueueWithMissingConfiguration() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let preferences = AnalyticsPreferences(userDefaults: isolatedUserDefaults())
        let queue = AnalyticsQueue(rootURL: rootURL)
        let recorder = AnalyticsRecorder(
            preferences: preferences,
            configurationResult: .failure(.missingConfiguration),
            queue: queue,
            uploader: AnalyticsUploader(client: StubAnalyticsHTTPClient())
        )

        recorder.record(.appOpen)

        XCTAssertEqual(queue.eventCount, 0)
        XCTAssertEqual(recorder.status, .missingConfiguration)
    }

    func testDebugSnapshotDoesNotPublishRecorderChanges() throws {
        let preferences = AnalyticsPreferences(userDefaults: isolatedUserDefaults())
        let recorder = AnalyticsRecorder(
            preferences: preferences,
            configurationResult: .success(try testConfiguration()),
            uploader: AnalyticsUploader(client: StubAnalyticsHTTPClient())
        )
        var didPublishChange = false
        let cancellable = recorder.objectWillChange.sink {
            didPublishChange = true
        }

        _ = recorder.makeDebugSnapshot()

        XCTAssertFalse(didPublishChange)
        cancellable.cancel()
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "ClipboardMarkupAnalyticsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private func temporaryRootURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardMarkupAnalyticsTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func testConfiguration() throws -> AnalyticsConfiguration {
        try AnalyticsConfiguration(
            analyticsBaseURL: URL(string: "https://example.com/clipboard-markup")!,
            appVersion: "1.2.3",
            audience: .test,
            analyticsKeyID: "clipboard-markup",
            analyticsSecret: "secret"
        )
    }
}
