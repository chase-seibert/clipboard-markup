import Combine
import Foundation
import OSLog

@MainActor
public protocol AnalyticsRecording: AnyObject {
    func record(_ kind: AnalyticsEventKind)
}

public enum AnalyticsStatus: Equatable {
    case enabled
    case disabled
    case missingConfiguration
    case paused(Date)
    case stoppedByServer
    case configurationError(String)

    public var displayText: String {
        switch self {
        case .enabled:
            "Analytics enabled"
        case .disabled:
            "Analytics disabled"
        case .missingConfiguration:
            "Analytics config missing"
        case let .paused(date):
            "Analytics paused until \(DateFormatting.absolute.string(from: date))"
        case .stoppedByServer:
            "Analytics stopped by server"
        case let .configurationError(message):
            message
        }
    }
}

@MainActor
public final class AnalyticsRecorder: ObservableObject, AnalyticsRecording {
    @Published public private(set) var status: AnalyticsStatus = .missingConfiguration

    public let preferences: AnalyticsPreferences

    private let queue: AnalyticsQueue
    private let uploader: AnalyticsUploader
    private let logger: Logger
    private var configurationResult: Result<AnalyticsConfiguration, AnalyticsConfigurationLoadError>
    private var sessionID = UUID().uuidString
    private var didRecordAppOpen = false
    private var heartbeatTimer: Timer?
    private var uploadTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var lastLoggedStatus: AnalyticsStatus?

    public convenience init() {
        self.init(preferences: AnalyticsPreferences())
    }

    public convenience init(preferences: AnalyticsPreferences) {
        self.init(
            preferences: preferences,
            configurationResult: AnalyticsConfiguration.loadDefault()
        )
    }

    init(
        preferences: AnalyticsPreferences,
        configurationResult: Result<AnalyticsConfiguration, AnalyticsConfigurationLoadError>,
        queue: AnalyticsQueue = AnalyticsQueue(),
        uploader: AnalyticsUploader = AnalyticsUploader(),
        logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.chaseseibert.ClipboardMarkup", category: "Analytics")
    ) {
        self.preferences = preferences
        self.configurationResult = configurationResult
        self.queue = queue
        self.uploader = uploader
        self.logger = logger
        updateStatus()

        preferences.$isSharingEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                guard let self else {
                    return
                }
                if !isEnabled {
                    queue.clear()
                }
                updateStatus()
                if isEnabled {
                    scheduleFlush()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        heartbeatTimer?.invalidate()
        uploadTask?.cancel()
    }

    public func start() {
        guard !didRecordAppOpen else {
            return
        }

        didRecordAppOpen = true
        record(.appOpen)
        startHeartbeatTimer()
        scheduleFlush()
    }

    public func setSharingEnabled(_ isEnabled: Bool) {
        preferences.setSharingEnabled(isEnabled)
    }

    public func record(_ kind: AnalyticsEventKind) {
        guard preferences.isSharingEnabled else {
            updateStatus()
            return
        }
        guard !preferences.isStoppedByServer else {
            updateStatus()
            return
        }
        guard let configuration = activeConfiguration() else {
            updateStatus()
            return
        }

        let event = AnalyticsBatchBuilder.makeEvent(
            kind: kind,
            audience: configuration.audience,
            sessionId: sessionID,
            installId: preferences.installID,
            now: Date()
        )
        queue.enqueue(event)
        updateStatus()
        scheduleFlush()
    }

    public func flushSoon() {
        scheduleFlush()
    }

    public func makeDebugSnapshot() -> AnalyticsDebugSnapshot {
        return AnalyticsDebugSnapshot(
            status: status,
            isSharingEnabled: preferences.isSharingEnabled,
            isStoppedByServer: preferences.isStoppedByServer,
            installID: preferences.installID,
            sessionID: sessionID,
            configuration: makeConfigurationDebugSummary(),
            queue: queue.makeDebugSnapshot()
        )
    }

    private func activeConfiguration() -> AnalyticsConfiguration? {
        guard case let .success(configuration) = configurationResult else {
            return nil
        }

        if let redirectBaseURL = preferences.redirectBaseURL,
           let redirectedConfiguration = try? configuration.replacingBaseURL(redirectBaseURL) {
            return redirectedConfiguration
        }

        return configuration
    }

    private func makeConfigurationDebugSummary() -> AnalyticsConfigurationDebugSummary {
        switch configurationResult {
        case let .success(configuration):
            return AnalyticsConfigurationDebugSummary(
                isConfigured: true,
                statusText: "Configured",
                baseURLString: configuration.analyticsBaseURL.absoluteString,
                namespace: configuration.namespace,
                appName: configuration.appName,
                appVersion: configuration.appVersion,
                platform: configuration.appPlatform,
                audience: configuration.audience,
                keyID: configuration.analyticsKeyID,
                redirectedBaseURLString: preferences.redirectBaseURLString
            )
        case let .failure(error):
            return AnalyticsConfigurationDebugSummary(
                isConfigured: false,
                statusText: error.localizedDescription,
                baseURLString: nil,
                namespace: nil,
                appName: nil,
                appVersion: nil,
                platform: nil,
                audience: nil,
                keyID: nil,
                redirectedBaseURLString: preferences.redirectBaseURLString
            )
        }
    }

    private func scheduleFlush() {
        guard uploadTask == nil else {
            return
        }

        uploadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            await self?.flush()
        }
    }

    private func flush() async {
        defer {
            uploadTask = nil
            updateStatus()
        }

        guard preferences.isSharingEnabled,
              !preferences.isStoppedByServer,
              let configuration = activeConfiguration(),
              queue.isReadyToUpload()
        else {
            return
        }

        do {
            guard let batch = try queue.prepareBatch(configuration: configuration) else {
                return
            }

            let decision = await uploader.upload(
                batch: batch,
                configuration: configuration,
                redirectBaseURL: nil
            )
            handle(decision)
        } catch {
            logger.error("Analytics flush failed: \(error.localizedDescription, privacy: .public)")
            _ = queue.scheduleRetry()
        }
    }

    private func handle(_ decision: AnalyticsUploadDecision) {
        switch decision {
        case let .success(redirectBaseURL):
            if let redirectBaseURL {
                preferences.setRedirectBaseURL(redirectBaseURL)
                logger.info("Analytics redirect persisted")
            }
            queue.markPreparedBatchUploaded()
            scheduleFlush()
        case let .retry(after):
            let minimumDelay = max(60, after.timeIntervalSinceNow)
            _ = queue.scheduleRetry(after: minimumDelay)
        case .stopLogging:
            preferences.setStoppedByServer(true)
            queue.clear()
        case let .permanentFailure(code):
            logger.error("Dropping analytics batch after permanent failure: \(code, privacy: .public)")
            queue.dropPreparedBatchAndEvents()
            scheduleFlush()
        }
    }

    private func updateStatus() {
        let nextStatus: AnalyticsStatus
        if !preferences.isSharingEnabled {
            nextStatus = .disabled
        } else if preferences.isStoppedByServer {
            nextStatus = .stoppedByServer
        } else {
            switch configurationResult {
            case .success:
                if let nextRetryAt = queue.nextRetryAt, nextRetryAt > Date() {
                    nextStatus = .paused(nextRetryAt)
                } else {
                    nextStatus = .enabled
                }
            case let .failure(error):
                switch error {
                case .missingConfiguration:
                    nextStatus = .missingConfiguration
                case .unreadableConfiguration, .invalidConfiguration:
                    nextStatus = .configurationError(error.localizedDescription)
                }
            }
        }

        if lastLoggedStatus != nextStatus {
            logStatusChange(nextStatus)
            lastLoggedStatus = nextStatus
        }
        status = nextStatus
    }

    private func logStatusChange(_ status: AnalyticsStatus) {
        switch status {
        case .enabled:
            logger.info("Analytics configured")
        case .disabled:
            logger.info("Analytics disabled by user")
        case .missingConfiguration:
            logger.info("Analytics unconfigured")
        case let .paused(date):
            logger.info("Analytics paused until \(date.formatted(), privacy: .public)")
        case .stoppedByServer:
            logger.info("Analytics stopped by server")
        case let .configurationError(message):
            logger.error("Analytics config error: \(message, privacy: .public)")
        }
    }

    private func startHeartbeatTimer() {
        guard heartbeatTimer == nil else {
            return
        }

        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.record(.appSessionHeartbeat)
            }
        }
    }
}
