import CryptoKit
import Foundation
import zlib

struct AnalyticsEventRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let eventId: String
    let type: String
    let occurredAt: Date
    let audience: AnalyticsAudience
    let sessionId: String
    let properties: AnalyticsEventProperties
    let enqueuedAt: Date
}

struct AnalyticsEventProperties: Codable, Equatable {
    let value: String?
    let count: Int?
    let installId: String
}

struct AnalyticsPayload: Codable, Equatable {
    let schemaVersion: Int
    let batchId: String
    let sentAt: Date
    let app: AnalyticsAppPayload
    let events: [AnalyticsPayloadEvent]
}

struct AnalyticsAppPayload: Codable, Equatable {
    let name: String
    let version: String
    let platform: String
}

struct AnalyticsPayloadEvent: Codable, Equatable {
    let eventId: String
    let type: String
    let occurredAt: Date
    let audience: AnalyticsAudience
    let sessionId: String
    let properties: AnalyticsEventProperties
}

struct AnalyticsPreparedBatch: Codable, Equatable {
    let batchId: String
    let eventIds: [UUID]
    let audience: AnalyticsAudience
    let gzippedPayload: Data
    let payloadSHA256: String
    let signature: String
    let createdAt: Date
    let uncompressedByteCount: Int
    let compressedByteCount: Int
}

struct AnalyticsSyncedBatchRecord: Codable, Equatable, Identifiable {
    var id: String { batchId }

    let batchId: String
    let uploadedAt: Date
    let eventCount: Int
    let audience: AnalyticsAudience
    let eventTypes: [String]
    let uncompressedByteCount: Int
    let compressedByteCount: Int
}

struct AnalyticsQueueState: Codable, Equatable {
    var events: [AnalyticsEventRecord]
    var preparedBatch: AnalyticsPreparedBatch?
    var retryAttempt: Int
    var nextRetryAt: Date?
    var syncedBatches: [AnalyticsSyncedBatchRecord]
    var successfullySyncedEventCount: Int

    static let empty = AnalyticsQueueState(
        events: [],
        preparedBatch: nil,
        retryAttempt: 0,
        nextRetryAt: nil,
        syncedBatches: [],
        successfullySyncedEventCount: 0
    )

    enum CodingKeys: String, CodingKey {
        case events
        case preparedBatch
        case retryAttempt
        case nextRetryAt
        case syncedBatches
        case successfullySyncedEventCount
    }

    init(
        events: [AnalyticsEventRecord],
        preparedBatch: AnalyticsPreparedBatch?,
        retryAttempt: Int,
        nextRetryAt: Date?,
        syncedBatches: [AnalyticsSyncedBatchRecord],
        successfullySyncedEventCount: Int
    ) {
        self.events = events
        self.preparedBatch = preparedBatch
        self.retryAttempt = retryAttempt
        self.nextRetryAt = nextRetryAt
        self.syncedBatches = syncedBatches
        self.successfullySyncedEventCount = successfullySyncedEventCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.events = try container.decode([AnalyticsEventRecord].self, forKey: .events)
        self.preparedBatch = try container.decodeIfPresent(AnalyticsPreparedBatch.self, forKey: .preparedBatch)
        self.retryAttempt = try container.decode(Int.self, forKey: .retryAttempt)
        self.nextRetryAt = try container.decodeIfPresent(Date.self, forKey: .nextRetryAt)
        self.syncedBatches = try container.decodeIfPresent([AnalyticsSyncedBatchRecord].self, forKey: .syncedBatches) ?? []
        self.successfullySyncedEventCount = try container.decodeIfPresent(
            Int.self,
            forKey: .successfullySyncedEventCount
        ) ?? self.syncedBatches.reduce(0) { $0 + $1.eventCount }
    }
}

struct AnalyticsServerResponse: Decodable, Equatable {
    struct ServerError: Decodable, Equatable {
        let code: String
        let message: String?
    }

    let schemaVersion: Int?
    let accepted: Bool?
    let duplicate: Bool?
    let action: String?
    let redirectBaseUrl: String?
    let retryAfterSeconds: TimeInterval?
    let error: ServerError?
}

enum AnalyticsUploadDecision: Equatable {
    case success(redirectBaseURL: URL?)
    case retry(after: Date)
    case stopLogging
    case permanentFailure(String)
}

public struct AnalyticsDebugSnapshot: Equatable {
    public let status: AnalyticsStatus
    public let isSharingEnabled: Bool
    public let isStoppedByServer: Bool
    public let installID: String
    public let sessionID: String
    public let configuration: AnalyticsConfigurationDebugSummary
    public let queue: AnalyticsQueueDebugSnapshot
}

public struct AnalyticsConfigurationDebugSummary: Equatable {
    public let isConfigured: Bool
    public let statusText: String
    public let baseURLString: String?
    public let namespace: String?
    public let appName: String?
    public let appVersion: String?
    public let platform: String?
    public let audience: AnalyticsAudience?
    public let keyID: String?
    public let redirectedBaseURLString: String?
}

public struct AnalyticsQueueDebugSnapshot: Equatable {
    public let rootPath: String
    public let statePath: String
    public let queuedEventCount: Int
    public let successfullySyncedEventCount: Int
    public let totalEventCount: Int
    public let preparedBatchID: String?
    public let preparedBatchEventCount: Int
    public let preparedBatchCompressedBytes: Int?
    public let retryAttempt: Int
    public let nextRetryAt: Date?
    public let recentQueuedEvents: [AnalyticsDebugEvent]
    public let recentSyncedBatches: [AnalyticsDebugSyncedBatch]
}

public struct AnalyticsDebugEvent: Identifiable, Equatable {
    public let id: UUID
    public let type: String
    public let value: String?
    public let audience: AnalyticsAudience
    public let occurredAt: Date
    public let enqueuedAt: Date
}

public struct AnalyticsDebugSyncedBatch: Identifiable, Equatable {
    public let id: String
    public let batchId: String
    public let uploadedAt: Date
    public let eventCount: Int
    public let audience: AnalyticsAudience
    public let eventTypes: [String]
    public let uncompressedByteCount: Int
    public let compressedByteCount: Int
}

enum AnalyticsBatchBuilder {
    static let apiVersion = "v1"
    static let maxEventsPerBatch = 500
    static let maxCompressedByteCount = 1_048_576
    static let maxUncompressedByteCount = 5_242_880

    static func makeEvent(
        kind: AnalyticsEventKind,
        audience: AnalyticsAudience,
        sessionId: String,
        installId: String,
        now: Date
    ) -> AnalyticsEventRecord {
        let eventId = UUID().uuidString
        return AnalyticsEventRecord(
            id: UUID(),
            eventId: eventId,
            type: kind.type,
            occurredAt: now,
            audience: audience,
            sessionId: sessionId,
            properties: AnalyticsEventProperties(
                value: kind.value,
                count: nil,
                installId: installId
            ),
            enqueuedAt: now
        )
    }

    static func makePreparedBatch(
        events: [AnalyticsEventRecord],
        configuration: AnalyticsConfiguration,
        batchId: String = UUID().uuidString,
        sentAt: Date
    ) throws -> AnalyticsPreparedBatch {
        guard !events.isEmpty else {
            throw AnalyticsError.emptyBatch
        }

        let audience = events[0].audience
        guard events.allSatisfy({ $0.audience == audience }) else {
            throw AnalyticsError.mixedAudienceBatch
        }

        let payload = AnalyticsPayload(
            schemaVersion: 1,
            batchId: batchId,
            sentAt: sentAt,
            app: AnalyticsAppPayload(
                name: configuration.appName,
                version: configuration.appVersion,
                platform: configuration.appPlatform
            ),
            events: events.map {
                AnalyticsPayloadEvent(
                    eventId: $0.eventId,
                    type: $0.type,
                    occurredAt: $0.occurredAt,
                    audience: $0.audience,
                    sessionId: $0.sessionId,
                    properties: $0.properties
                )
            }
        )

        let uncompressedData = try JSONEncoder.analytics.encode(payload)
        guard uncompressedData.count <= maxUncompressedByteCount else {
            throw AnalyticsError.payloadTooLarge
        }

        let gzippedData = try AnalyticsGzip.compress(uncompressedData)
        guard gzippedData.count <= maxCompressedByteCount else {
            throw AnalyticsError.payloadTooLarge
        }

        let payloadSHA = AnalyticsCrypto.sha256Hex(gzippedData)
        let signature = AnalyticsCrypto.signatureHex(
            namespace: configuration.namespace,
            apiVersion: apiVersion,
            batchId: batchId,
            payloadSHA256: payloadSHA,
            secret: configuration.analyticsSecret
        )

        return AnalyticsPreparedBatch(
            batchId: batchId,
            eventIds: events.map(\.id),
            audience: audience,
            gzippedPayload: gzippedData,
            payloadSHA256: payloadSHA,
            signature: signature,
            createdAt: sentAt,
            uncompressedByteCount: uncompressedData.count,
            compressedByteCount: gzippedData.count
        )
    }
}

enum AnalyticsCrypto {
    static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func signatureHex(
        namespace: String,
        apiVersion: String,
        batchId: String,
        payloadSHA256: String,
        secret: String
    ) -> String {
        let signingString = [
            namespace,
            apiVersion,
            batchId,
            payloadSHA256
        ].joined(separator: "\n")
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(signingString.utf8), using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }
}

enum AnalyticsGzip {
    static func compress(_ data: Data) throws -> Data {
        try data.withUnsafeBytes { rawBuffer in
            var stream = z_stream()
            var output = Data()

            let initStatus = deflateInit2_(
                &stream,
                Z_DEFAULT_COMPRESSION,
                Z_DEFLATED,
                MAX_WBITS + 16,
                MAX_MEM_LEVEL,
                Z_DEFAULT_STRATEGY,
                ZLIB_VERSION,
                Int32(MemoryLayout<z_stream>.size)
            )
            guard initStatus == Z_OK else {
                throw AnalyticsError.gzipFailed(initStatus)
            }
            defer {
                deflateEnd(&stream)
            }

            stream.next_in = UnsafeMutablePointer<Bytef>(
                mutating: rawBuffer.bindMemory(to: Bytef.self).baseAddress
            )
            stream.avail_in = uInt(data.count)

            let chunkSize = 16_384
            var status: Int32 = Z_OK
            repeat {
                var chunk = [UInt8](repeating: 0, count: chunkSize)
                chunk.withUnsafeMutableBytes { chunkBuffer in
                    stream.next_out = chunkBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(chunkSize)
                    status = deflate(&stream, Z_FINISH)

                    let written = chunkSize - Int(stream.avail_out)
                    if written > 0 {
                        output.append(chunkBuffer.bindMemory(to: UInt8.self).baseAddress!, count: written)
                    }
                }
            } while status == Z_OK

            guard status == Z_STREAM_END else {
                throw AnalyticsError.gzipFailed(status)
            }

            return output
        }
    }

    static func decompress(_ data: Data) throws -> Data {
        try data.withUnsafeBytes { rawBuffer in
            var stream = z_stream()
            var output = Data()

            let initStatus = inflateInit2_(
                &stream,
                MAX_WBITS + 16,
                ZLIB_VERSION,
                Int32(MemoryLayout<z_stream>.size)
            )
            guard initStatus == Z_OK else {
                throw AnalyticsError.gzipFailed(initStatus)
            }
            defer {
                inflateEnd(&stream)
            }

            stream.next_in = UnsafeMutablePointer<Bytef>(
                mutating: rawBuffer.bindMemory(to: Bytef.self).baseAddress
            )
            stream.avail_in = uInt(data.count)

            let chunkSize = 16_384
            var status: Int32 = Z_OK
            repeat {
                var chunk = [UInt8](repeating: 0, count: chunkSize)
                chunk.withUnsafeMutableBytes { chunkBuffer in
                    stream.next_out = chunkBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(chunkSize)
                    status = inflate(&stream, Z_NO_FLUSH)

                    let written = chunkSize - Int(stream.avail_out)
                    if written > 0 {
                        output.append(chunkBuffer.bindMemory(to: UInt8.self).baseAddress!, count: written)
                    }
                }
            } while status == Z_OK

            guard status == Z_STREAM_END else {
                throw AnalyticsError.gzipFailed(status)
            }

            return output
        }
    }
}

enum AnalyticsError: LocalizedError, Equatable {
    case emptyBatch
    case mixedAudienceBatch
    case payloadTooLarge
    case gzipFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .emptyBatch:
            "Analytics batch is empty."
        case .mixedAudienceBatch:
            "Analytics batch contains multiple audiences."
        case .payloadTooLarge:
            "Analytics payload is too large."
        case let .gzipFailed(code):
            "Analytics gzip failed with zlib code \(code)."
        }
    }
}

extension JSONEncoder {
    static var analytics: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var analytics: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
