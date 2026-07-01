@testable import ClipboardMarkupCore
import XCTest

final class AnalyticsQueueTests: XCTestCase {
    func testQueuePersistsEventsAndPreparedBatch() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let queue = AnalyticsQueue(rootURL: rootURL)
        let configuration = try testConfiguration()
        let now = Date(timeIntervalSince1970: 1_779_999_600)
        let event = AnalyticsBatchBuilder.makeEvent(
            kind: .appOpen,
            audience: .test,
            sessionId: "session",
            installId: "install",
            now: now
        )

        queue.enqueue(event, now: now)
        let batch = try queue.prepareBatch(configuration: configuration, now: now)

        XCTAssertEqual(queue.eventCount, 1)
        XCTAssertTrue(queue.hasPreparedBatch)
        XCTAssertEqual(batch?.eventIds, [event.id])
        XCTAssertEqual(queue.makeDebugSnapshot().successfullySyncedEventCount, 0)
        XCTAssertEqual(queue.makeDebugSnapshot().totalEventCount, 1)

        let reloadedQueue = AnalyticsQueue(rootURL: rootURL)
        XCTAssertEqual(reloadedQueue.eventCount, 1)
        XCTAssertTrue(reloadedQueue.hasPreparedBatch)
    }

    func testUploadedBatchRemovesOnlyUploadedEvents() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let queue = AnalyticsQueue(rootURL: rootURL)
        let configuration = try testConfiguration()
        let now = Date()
        let first = AnalyticsBatchBuilder.makeEvent(
            kind: .appOpen,
            audience: .test,
            sessionId: "session",
            installId: "install",
            now: now
        )
        let second = AnalyticsBatchBuilder.makeEvent(
            kind: .appOpen,
            audience: .debug,
            sessionId: "session",
            installId: "install",
            now: now
        )

        queue.enqueue(first, now: now)
        queue.enqueue(second, now: now)
        _ = try queue.prepareBatch(configuration: configuration, now: now)
        queue.markPreparedBatchUploaded()

        XCTAssertEqual(queue.eventCount, 1)
        XCTAssertFalse(queue.hasPreparedBatch)
    }

    func testUploadedBatchAppearsInDebugSyncedHistoryAndPersists() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let queue = AnalyticsQueue(rootURL: rootURL)
        let configuration = try testConfiguration()
        let now = Date(timeIntervalSince1970: 1_779_999_600)
        let uploadedAt = now.addingTimeInterval(10)
        queue.enqueue(
            AnalyticsBatchBuilder.makeEvent(
                kind: .clipCaptured(.image),
                audience: .test,
                sessionId: "session",
                installId: "install",
                now: now
            ),
            now: now
        )
        queue.enqueue(
            AnalyticsBatchBuilder.makeEvent(
                kind: .clipAction(.copy),
                audience: .test,
                sessionId: "session",
                installId: "install",
                now: now
            ),
            now: now
        )

        _ = try queue.prepareBatch(configuration: configuration, now: now)
        queue.markPreparedBatchUploaded(now: uploadedAt)

        let snapshot = queue.makeDebugSnapshot()
        XCTAssertEqual(snapshot.queuedEventCount, 0)
        XCTAssertEqual(snapshot.successfullySyncedEventCount, 2)
        XCTAssertEqual(snapshot.totalEventCount, 2)
        XCTAssertNil(snapshot.preparedBatchID)
        XCTAssertEqual(snapshot.recentSyncedBatches.count, 1)
        XCTAssertEqual(snapshot.recentSyncedBatches.first?.eventCount, 2)
        XCTAssertEqual(snapshot.recentSyncedBatches.first?.audience, .test)
        XCTAssertEqual(snapshot.recentSyncedBatches.first?.eventTypes, ["clip.action", "clip.captured"])
        XCTAssertEqual(snapshot.recentSyncedBatches.first?.uploadedAt, uploadedAt)
        XCTAssertNotEqual(snapshot.recentSyncedBatches.first?.compressedByteCount, 0)

        let reloadedSnapshot = AnalyticsQueue(rootURL: rootURL).makeDebugSnapshot()
        XCTAssertEqual(reloadedSnapshot.recentSyncedBatches, snapshot.recentSyncedBatches)
    }

    func testDebugSyncedHistoryIsCappedToRecentBatches() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let queue = AnalyticsQueue(rootURL: rootURL)
        let configuration = try testConfiguration()
        let now = Date(timeIntervalSince1970: 1_779_999_600)

        for index in 0..<25 {
            let date = now.addingTimeInterval(TimeInterval(index))
            queue.enqueue(
                AnalyticsBatchBuilder.makeEvent(
                    kind: .appOpen,
                    audience: .test,
                    sessionId: "session",
                    installId: "install",
                    now: date
                ),
                now: date
            )
            _ = try queue.prepareBatch(configuration: configuration, now: date)
            queue.markPreparedBatchUploaded(now: date)
        }

        let syncedBatches = queue.makeDebugSnapshot().recentSyncedBatches
        XCTAssertEqual(syncedBatches.count, 20)
        XCTAssertEqual(syncedBatches.first?.uploadedAt, now.addingTimeInterval(24))
        XCTAssertEqual(syncedBatches.last?.uploadedAt, now.addingTimeInterval(5))
        XCTAssertEqual(queue.makeDebugSnapshot().successfullySyncedEventCount, 25)
        XCTAssertEqual(queue.makeDebugSnapshot().totalEventCount, 25)
    }

    func testRetryStatePersistsAndBlocksUntilEligible() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let queue = AnalyticsQueue(rootURL: rootURL)
        let now = Date()
        queue.enqueue(
            AnalyticsBatchBuilder.makeEvent(
                kind: .appOpen,
                audience: .test,
                sessionId: "session",
                installId: "install",
                now: now
            ),
            now: now
        )
        let retryAt = queue.scheduleRetry(after: 3_600, now: now)

        XCTAssertFalse(queue.isReadyToUpload(now: retryAt.addingTimeInterval(-1)))
        XCTAssertTrue(queue.isReadyToUpload(now: retryAt))

        let reloadedQueue = AnalyticsQueue(rootURL: rootURL)
        XCTAssertNotNil(reloadedQueue.nextRetryAt)
        XCTAssertEqual(reloadedQueue.nextRetryAt!.timeIntervalSince1970, retryAt.timeIntervalSince1970, accuracy: 1.0)
    }

    func testExpiredEventsArePrunedAfterRetentionHorizon() throws {
        let rootURL = temporaryRootURL()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let queue = AnalyticsQueue(rootURL: rootURL)
        let configuration = try testConfiguration()
        let now = Date()
        let expiredDate = now.addingTimeInterval(-AnalyticsQueue.retentionInterval - 1)
        let expired = AnalyticsBatchBuilder.makeEvent(
            kind: .appOpen,
            audience: .test,
            sessionId: "session",
            installId: "install",
            now: expiredDate
        )

        queue.enqueue(expired, now: expiredDate)
        let batch = try queue.prepareBatch(configuration: configuration, now: now)

        XCTAssertNil(batch)
        XCTAssertEqual(queue.eventCount, 0)
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
