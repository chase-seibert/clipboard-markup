import Foundation
import OSLog

struct AnalyticsHTTPClientResponse {
    let statusCode: Int
    let data: Data
    let headers: [AnyHashable: Any]
}

protocol AnalyticsHTTPClient {
    func upload(_ request: URLRequest) async throws -> AnalyticsHTTPClientResponse
}

struct URLSessionAnalyticsHTTPClient: AnalyticsHTTPClient {
    func upload(_ request: URLRequest) async throws -> AnalyticsHTTPClientResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return AnalyticsHTTPClientResponse(
            statusCode: httpResponse.statusCode,
            data: data,
            headers: httpResponse.allHeaderFields
        )
    }
}

final class AnalyticsUploader {
    private let client: AnalyticsHTTPClient
    private let logger: Logger

    init(
        client: AnalyticsHTTPClient = URLSessionAnalyticsHTTPClient(),
        logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.chaseseibert.ClipboardMarkup", category: "Analytics")
    ) {
        self.client = client
        self.logger = logger
    }

    func upload(
        batch: AnalyticsPreparedBatch,
        configuration: AnalyticsConfiguration,
        redirectBaseURL: URL?
    ) async -> AnalyticsUploadDecision {
        do {
            let effectiveConfiguration: AnalyticsConfiguration
            if let redirectBaseURL {
                effectiveConfiguration = try configuration.replacingBaseURL(redirectBaseURL)
            } else {
                effectiveConfiguration = configuration
            }

            var request = URLRequest(url: effectiveConfiguration.uploadURL)
            request.httpMethod = "POST"
            request.httpBody = batch.gzippedPayload
            request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(batch.batchId, forHTTPHeaderField: "X-App-Analytics-Batch-ID")
            request.setValue(batch.payloadSHA256, forHTTPHeaderField: "X-App-Analytics-Payload-SHA256")
            request.setValue(configuration.analyticsKeyID, forHTTPHeaderField: "X-App-Analytics-Key-ID")
            request.setValue(batch.signature, forHTTPHeaderField: "X-App-Analytics-Signature")

            let response = try await client.upload(request)
            return decision(for: response, now: Date())
        } catch {
            logger.info("Analytics upload network error; will retry: \(error.localizedDescription, privacy: .public)")
            return .retry(after: Date().addingTimeInterval(60))
        }
    }

    func decision(
        for response: AnalyticsHTTPClientResponse,
        now: Date
    ) -> AnalyticsUploadDecision {
        let serverResponse = try? JSONDecoder.analytics.decode(AnalyticsServerResponse.self, from: response.data)

        if serverResponse?.action == "stop_logging" {
            logger.info("Analytics server requested stop_logging")
            return .stopLogging
        }

        if response.statusCode == 202 || (response.statusCode == 200 && serverResponse?.duplicate == true) {
            let redirectURL = serverResponse?.action == "redirect"
                ? serverResponse?.redirectBaseUrl.flatMap(URL.init(string:))
                : nil
            if redirectURL != nil {
                logger.info("Analytics server provided redirect")
            } else {
                logger.info("Analytics upload succeeded")
            }
            return .success(redirectBaseURL: redirectURL)
        }

        if response.statusCode == 429 ||
            response.statusCode >= 500 ||
            serverResponse?.action == "pause_uploads" ||
            serverResponse?.error?.code == "INGEST_PAUSED" {
            let retryAfter = retryAfterDelay(response: response, serverResponse: serverResponse)
            let retryDate = now.addingTimeInterval(max(60, retryAfter ?? 60))
            logger.info("Analytics upload paused or retryable; will retry")
            return .retry(after: retryDate)
        }

        if (400..<500).contains(response.statusCode) {
            let code = serverResponse?.error?.code ?? "HTTP_\(response.statusCode)"
            logger.error("Analytics upload permanent failure: \(code, privacy: .public)")
            return .permanentFailure(code)
        }

        return .retry(after: now.addingTimeInterval(60))
    }

    private func retryAfterDelay(
        response: AnalyticsHTTPClientResponse,
        serverResponse: AnalyticsServerResponse?
    ) -> TimeInterval? {
        if let retryAfterSeconds = serverResponse?.retryAfterSeconds {
            return retryAfterSeconds
        }

        let retryAfterHeader = response.headers.first { key, _ in
            String(describing: key).localizedCaseInsensitiveCompare("Retry-After") == .orderedSame
        }?.value

        guard let retryAfterHeader else {
            return nil
        }

        if let seconds = TimeInterval(String(describing: retryAfterHeader)) {
            return seconds
        }

        if let date = HTTPDateFormatter.formatter.date(from: String(describing: retryAfterHeader)) {
            return max(0, date.timeIntervalSinceNow)
        }

        return nil
    }
}

private enum HTTPDateFormatter {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        return formatter
    }()
}
