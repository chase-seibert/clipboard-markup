@testable import ClipboardMarkupCore
import XCTest

final class AnalyticsBatchBuilderTests: XCTestCase {
    func testGzipRoundTrip() throws {
        let input = Data("hello analytics".utf8)

        let compressed = try AnalyticsGzip.compress(input)
        let decompressed = try AnalyticsGzip.decompress(compressed)

        XCTAssertNotEqual(compressed, input)
        XCTAssertEqual(decompressed, input)
    }

    func testCryptoFixtures() throws {
        XCTAssertEqual(
            AnalyticsCrypto.sha256Hex(Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        XCTAssertEqual(
            AnalyticsCrypto.signatureHex(
                namespace: "ns",
                apiVersion: "v1",
                batchId: "batch",
                payloadSHA256: "abc",
                secret: "key"
            ),
            "d4f5bfc626268e9e7d59e0d8495fe5903ed8df27256a9620d5ec7b78448ff7d8"
        )
    }

    func testPreparedBatchEncodesExpectedPayloadAndSignature() throws {
        let configuration = try testConfiguration()
        let now = Date(timeIntervalSince1970: 1_779_999_600)
        let event = AnalyticsBatchBuilder.makeEvent(
            kind: .clipCaptured(.image),
            audience: .test,
            sessionId: "session-1",
            installId: "install-1",
            now: now
        )

        let batch = try AnalyticsBatchBuilder.makePreparedBatch(
            events: [event],
            configuration: configuration,
            batchId: "batch-1",
            sentAt: now
        )

        XCTAssertEqual(batch.batchId, "batch-1")
        XCTAssertEqual(batch.eventIds, [event.id])
        XCTAssertEqual(batch.audience, .test)
        XCTAssertEqual(batch.payloadSHA256, AnalyticsCrypto.sha256Hex(batch.gzippedPayload))
        XCTAssertEqual(
            batch.signature,
            AnalyticsCrypto.signatureHex(
                namespace: "clipboard-markup",
                apiVersion: "v1",
                batchId: "batch-1",
                payloadSHA256: batch.payloadSHA256,
                secret: "secret"
            )
        )

        let payload = try JSONDecoder.analytics.decode(
            AnalyticsPayload.self,
            from: try AnalyticsGzip.decompress(batch.gzippedPayload)
        )
        XCTAssertEqual(payload.schemaVersion, 1)
        XCTAssertEqual(payload.batchId, "batch-1")
        XCTAssertEqual(payload.app.name, "clipboard-markup")
        XCTAssertEqual(payload.app.version, "1.2.3")
        XCTAssertEqual(payload.app.platform, "macOS")
        XCTAssertEqual(payload.events.first?.type, "clip.captured")
        XCTAssertEqual(payload.events.first?.properties.value, "image")
        XCTAssertEqual(payload.events.first?.properties.installId, "install-1")
    }

    func testEventPropertiesDoNotAllowClipboardDerivedFields() throws {
        let kinds: [AnalyticsEventKind] = [
            .appOpen,
            .appWindowOpened,
            .appMenuBarOpened,
            .appSessionHeartbeat,
            .clipCaptured(.richText),
            .clipAction(.copyOriginalImage),
            .libraryFilterChanged(.favorites),
            .searchOpened,
            .searchSubmitted,
            .settingsOpened,
            .settingsSectionOpened(.storageLocation),
            .storageLocationChanged(.dropbox)
        ]

        for kind in kinds {
            let event = AnalyticsBatchBuilder.makeEvent(
                kind: kind,
                audience: .test,
                sessionId: "session",
                installId: "install",
                now: Date()
            )
            let data = try JSONEncoder.analytics.encode(event.properties)
            let properties = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let keys = Set((properties ?? [:]).keys)
            XCTAssertTrue(keys.isSubset(of: Set(["installId", "value", "count"])))
            XCTAssertEqual(properties?["installId"] as? String, "install")
            XCTAssertNil(properties?["clipboard"])
            XCTAssertNil(properties?["query"])
            XCTAssertNil(properties?["path"])
            XCTAssertNil(properties?["filename"])
            XCTAssertNil(properties?["title"])
            XCTAssertNil(properties?["ocr"])
        }
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
