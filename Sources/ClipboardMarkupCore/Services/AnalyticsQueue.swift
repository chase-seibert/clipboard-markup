import Foundation
import OSLog

final class AnalyticsQueue {
    static let retentionInterval: TimeInterval = 90 * 24 * 60 * 60
    private static let syncedBatchLimit = 20

    private let fileManager: FileManager
    private let rootURL: URL
    private let stateURL: URL
    private let logger: Logger
    private var state: AnalyticsQueueState

    init(
        rootURL: URL = AnalyticsConfiguration.analyticsRootURL(),
        fileManager: FileManager = .default,
        logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.chaseseibert.ClipboardMarkup", category: "Analytics")
    ) {
        self.rootURL = rootURL
        self.stateURL = rootURL.appendingPathComponent("analytics-queue.json")
        self.fileManager = fileManager
        self.logger = logger
        self.state = Self.loadState(from: stateURL)
    }

    var nextRetryAt: Date? {
        state.nextRetryAt
    }

    var eventCount: Int {
        state.events.count
    }

    var hasPreparedBatch: Bool {
        state.preparedBatch != nil
    }

    func enqueue(_ event: AnalyticsEventRecord, now: Date = Date()) {
        pruneExpiredEvents(now: now)
        state.events.append(event)
        save()
        logger.info("Analytics event enqueued: \(event.type, privacy: .public)")
    }

    func clear() {
        state = .empty
        save()
    }

    func isReadyToUpload(now: Date = Date()) -> Bool {
        guard !state.events.isEmpty || state.preparedBatch != nil else {
            return false
        }

        guard let nextRetryAt = state.nextRetryAt else {
            return true
        }

        return nextRetryAt <= now
    }

    func prepareBatch(
        configuration: AnalyticsConfiguration,
        now: Date = Date()
    ) throws -> AnalyticsPreparedBatch? {
        pruneExpiredEvents(now: now)

        if let preparedBatch = state.preparedBatch {
            return preparedBatch
        }

        guard let firstEvent = state.events.first else {
            save()
            return nil
        }

        let audience = firstEvent.audience
        let candidates = state.events
            .filter { $0.audience == audience }
            .prefix(AnalyticsBatchBuilder.maxEventsPerBatch)

        var count = candidates.count
        while count > 0 {
            let batchEvents = Array(candidates.prefix(count))
            do {
                let batch = try AnalyticsBatchBuilder.makePreparedBatch(
                    events: batchEvents,
                    configuration: configuration,
                    sentAt: now
                )
                state.preparedBatch = batch
                state.retryAttempt = 0
                state.nextRetryAt = nil
                save()
                return batch
            } catch AnalyticsError.payloadTooLarge {
                count /= 2
            }
        }

        state.events.removeAll { $0.id == firstEvent.id }
        save()
        throw AnalyticsError.payloadTooLarge
    }

    func makeDebugSnapshot() -> AnalyticsQueueDebugSnapshot {
        AnalyticsQueueDebugSnapshot(
            rootPath: rootURL.path,
            statePath: stateURL.path,
            queuedEventCount: state.events.count,
            successfullySyncedEventCount: state.successfullySyncedEventCount,
            totalEventCount: state.successfullySyncedEventCount + state.events.count,
            preparedBatchID: state.preparedBatch?.batchId,
            preparedBatchEventCount: state.preparedBatch?.eventIds.count ?? 0,
            preparedBatchCompressedBytes: state.preparedBatch?.compressedByteCount,
            retryAttempt: state.retryAttempt,
            nextRetryAt: state.nextRetryAt,
            recentQueuedEvents: state.events.suffix(12).reversed().map { event in
                AnalyticsDebugEvent(
                    id: event.id,
                    type: event.type,
                    value: event.properties.value,
                    audience: event.audience,
                    occurredAt: event.occurredAt,
                    enqueuedAt: event.enqueuedAt
                )
            },
            recentSyncedBatches: state.syncedBatches.map { batch in
                AnalyticsDebugSyncedBatch(
                    id: batch.batchId,
                    batchId: batch.batchId,
                    uploadedAt: batch.uploadedAt,
                    eventCount: batch.eventCount,
                    audience: batch.audience,
                    eventTypes: batch.eventTypes,
                    uncompressedByteCount: batch.uncompressedByteCount,
                    compressedByteCount: batch.compressedByteCount
                )
            }
        )
    }

    func markPreparedBatchUploaded(now: Date = Date()) {
        guard let preparedBatch = state.preparedBatch else {
            return
        }

        let uploadedIDs = Set(preparedBatch.eventIds)
        let uploadedEvents = state.events.filter { uploadedIDs.contains($0.id) }
        state.events.removeAll { uploadedIDs.contains($0.id) }
        state.syncedBatches.insert(
            AnalyticsSyncedBatchRecord(
                batchId: preparedBatch.batchId,
                uploadedAt: now,
                eventCount: preparedBatch.eventIds.count,
                audience: preparedBatch.audience,
                eventTypes: Array(Set(uploadedEvents.map(\.type))).sorted(),
                uncompressedByteCount: preparedBatch.uncompressedByteCount,
                compressedByteCount: preparedBatch.compressedByteCount
            ),
            at: 0
        )
        if state.syncedBatches.count > Self.syncedBatchLimit {
            state.syncedBatches = Array(state.syncedBatches.prefix(Self.syncedBatchLimit))
        }
        state.successfullySyncedEventCount += preparedBatch.eventIds.count
        state.preparedBatch = nil
        state.retryAttempt = 0
        state.nextRetryAt = nil
        save()
    }

    func dropPreparedBatchAndEvents() {
        guard let preparedBatch = state.preparedBatch else {
            return
        }

        let droppedIDs = Set(preparedBatch.eventIds)
        state.events.removeAll { droppedIDs.contains($0.id) }
        state.preparedBatch = nil
        state.retryAttempt = 0
        state.nextRetryAt = nil
        save()
    }

    func scheduleRetry(after minimumDelay: TimeInterval? = nil, now: Date = Date()) -> Date {
        let nextAttempt = state.retryAttempt + 1
        let cappedDelay = min(24 * 60 * 60, 60 * pow(2, Double(max(0, nextAttempt - 1))))
        let jitteredDelay = Double.random(in: max(60, cappedDelay * 0.5)...max(60, cappedDelay))
        let retryDelay = max(minimumDelay ?? 0, jitteredDelay)
        let retryDate = now.addingTimeInterval(retryDelay)

        state.retryAttempt = nextAttempt
        state.nextRetryAt = retryDate
        save()
        logger.info("Analytics retry scheduled for \(retryDate.formatted(), privacy: .public)")
        return retryDate
    }

    private func pruneExpiredEvents(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.retentionInterval)
        let retainedEvents = state.events.filter { $0.enqueuedAt >= cutoff }
        guard retainedEvents.count != state.events.count else {
            return
        }

        let retainedIDs = Set(retainedEvents.map(\.id))
        state.events = retainedEvents
        if let preparedBatch = state.preparedBatch,
           !preparedBatch.eventIds.allSatisfy({ retainedIDs.contains($0) }) {
            state.preparedBatch = nil
            state.retryAttempt = 0
            state.nextRetryAt = nil
        }
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let data = try JSONEncoder.analytics.encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            logger.error("Analytics queue save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func loadState(from url: URL) -> AnalyticsQueueState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder.analytics.decode(AnalyticsQueueState.self, from: data)
        else {
            return .empty
        }

        return state
    }
}
