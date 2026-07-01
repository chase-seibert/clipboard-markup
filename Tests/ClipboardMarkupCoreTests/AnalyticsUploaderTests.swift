@testable import ClipboardMarkupCore
import XCTest

final class AnalyticsUploaderTests: XCTestCase {
    func testDecisionTreatsAcceptedAsSuccess() {
        let response = AnalyticsHTTPClientResponse(
            statusCode: 202,
            data: Data(#"{"accepted":true,"duplicate":false,"action":"continue"}"#.utf8),
            headers: [:]
        )

        let decision = AnalyticsUploader(client: StubAnalyticsHTTPClient()).decision(for: response, now: Date())

        XCTAssertEqual(decision, .success(redirectBaseURL: nil))
    }

    func testDecisionTreatsDuplicateAsSuccess() {
        let response = AnalyticsHTTPClientResponse(
            statusCode: 200,
            data: Data(#"{"accepted":true,"duplicate":true,"action":"continue"}"#.utf8),
            headers: [:]
        )

        let decision = AnalyticsUploader(client: StubAnalyticsHTTPClient()).decision(for: response, now: Date())

        XCTAssertEqual(decision, .success(redirectBaseURL: nil))
    }

    func testDecisionPersistsRedirectOnAcceptedResponse() {
        let response = AnalyticsHTTPClientResponse(
            statusCode: 202,
            data: Data(#"{"accepted":true,"duplicate":false,"action":"redirect","redirectBaseUrl":"https://redirect.example.com/clipboard-markup"}"#.utf8),
            headers: [:]
        )

        let decision = AnalyticsUploader(client: StubAnalyticsHTTPClient()).decision(for: response, now: Date())

        XCTAssertEqual(decision, .success(redirectBaseURL: URL(string: "https://redirect.example.com/clipboard-markup")))
    }

    func testDecisionRetriesPausedResponse() {
        let now = Date(timeIntervalSince1970: 1_000)
        let response = AnalyticsHTTPClientResponse(
            statusCode: 429,
            data: Data(#"{"accepted":false,"duplicate":false,"action":"pause_uploads","retryAfterSeconds":3600,"error":{"code":"INGEST_PAUSED"}}"#.utf8),
            headers: [:]
        )

        let decision = AnalyticsUploader(client: StubAnalyticsHTTPClient()).decision(for: response, now: now)

        guard case let .retry(after) = decision else {
            return XCTFail("Expected retry")
        }
        XCTAssertEqual(after.timeIntervalSince1970, now.addingTimeInterval(3_600).timeIntervalSince1970, accuracy: 0.001)
    }

    func testDecisionRetriesAwsStyle429WithoutJSON() {
        let now = Date(timeIntervalSince1970: 1_000)
        let response = AnalyticsHTTPClientResponse(
            statusCode: 429,
            data: Data(),
            headers: ["Retry-After": "120"]
        )

        let decision = AnalyticsUploader(client: StubAnalyticsHTTPClient()).decision(for: response, now: now)

        guard case let .retry(after) = decision else {
            return XCTFail("Expected retry")
        }
        XCTAssertEqual(after.timeIntervalSince1970, now.addingTimeInterval(120).timeIntervalSince1970, accuracy: 0.001)
    }

    func testDecisionStopsLogging() {
        let response = AnalyticsHTTPClientResponse(
            statusCode: 200,
            data: Data(#"{"accepted":false,"duplicate":false,"action":"stop_logging"}"#.utf8),
            headers: [:]
        )

        let decision = AnalyticsUploader(client: StubAnalyticsHTTPClient()).decision(for: response, now: Date())

        XCTAssertEqual(decision, .stopLogging)
    }

    func testDecisionDropsPermanentValidationFailure() {
        let response = AnalyticsHTTPClientResponse(
            statusCode: 400,
            data: Data(#"{"accepted":false,"duplicate":false,"action":"continue","error":{"code":"INVALID_SIGNATURE"}}"#.utf8),
            headers: [:]
        )

        let decision = AnalyticsUploader(client: StubAnalyticsHTTPClient()).decision(for: response, now: Date())

        XCTAssertEqual(decision, .permanentFailure("INVALID_SIGNATURE"))
    }

    func testUploadBuildsRequiredHeadersAndBody() async throws {
        let configuration = try AnalyticsConfiguration(
            analyticsBaseURL: URL(string: "https://example.com/clipboard-markup")!,
            appVersion: "1.2.3",
            audience: .test,
            analyticsKeyID: "clipboard-markup",
            analyticsSecret: "secret"
        )
        let event = AnalyticsBatchBuilder.makeEvent(
            kind: .appOpen,
            audience: .test,
            sessionId: "session",
            installId: "install",
            now: Date()
        )
        let batch = try AnalyticsBatchBuilder.makePreparedBatch(
            events: [event],
            configuration: configuration,
            batchId: "batch-1",
            sentAt: Date()
        )
        let client = StubAnalyticsHTTPClient(
            response: AnalyticsHTTPClientResponse(
                statusCode: 202,
                data: Data(#"{"accepted":true,"duplicate":false,"action":"continue"}"#.utf8),
                headers: [:]
            )
        )
        let uploader = AnalyticsUploader(client: client)

        let decision = await uploader.upload(batch: batch, configuration: configuration, redirectBaseURL: nil)

        XCTAssertEqual(decision, .success(redirectBaseURL: nil))
        XCTAssertEqual(client.requests.first?.url?.absoluteString, "https://example.com/clipboard-markup/v1/events")
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "Content-Encoding"), "gzip")
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "X-App-Analytics-Batch-ID"), "batch-1")
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "X-App-Analytics-Payload-SHA256"), batch.payloadSHA256)
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "X-App-Analytics-Key-ID"), "clipboard-markup")
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "X-App-Analytics-Signature"), batch.signature)
        XCTAssertEqual(client.requests.first?.httpBody, batch.gzippedPayload)
    }
}

final class StubAnalyticsHTTPClient: AnalyticsHTTPClient {
    var requests: [URLRequest] = []
    var response: AnalyticsHTTPClientResponse

    init(
        response: AnalyticsHTTPClientResponse = AnalyticsHTTPClientResponse(
            statusCode: 202,
            data: Data(#"{"accepted":true,"duplicate":false,"action":"continue"}"#.utf8),
            headers: [:]
        )
    ) {
        self.response = response
    }

    func upload(_ request: URLRequest) async throws -> AnalyticsHTTPClientResponse {
        requests.append(request)
        return response
    }
}
