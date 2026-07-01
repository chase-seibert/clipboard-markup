#if DEBUG
import AppKit
import Dispatch
import Foundation
import OSLog

@MainActor
public enum StartupTimingLogger {
    public enum OnceKey: Hashable {
        case firstPersistedImageLoad
        case firstVisibleImageThumbnail
        case mainWindowAppear
        case storagePreferencesInit
    }

    public struct Token {
        fileprivate let phase: String
        fileprivate let startedAt: DispatchTime
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.chaseseibert.ClipboardMarkup",
        category: "Startup"
    )
    private static let appStartedAt = DispatchTime.now()
    private static var loggedOnceKeys: Set<OnceKey> = []

    public static func mark(_ phase: String, metadata: String? = nil) {
        log(phase: phase, durationMilliseconds: nil, metadata: metadata)
    }

    public static func markOnce(_ key: OnceKey, _ phase: String, metadata: String? = nil) {
        guard loggedOnceKeys.insert(key).inserted else {
            return
        }

        mark(phase, metadata: metadata)
    }

    public static func begin(_ phase: String) -> Token {
        Token(phase: phase, startedAt: DispatchTime.now())
    }

    public static func beginOnce(_ key: OnceKey, _ phase: String) -> Token? {
        guard loggedOnceKeys.insert(key).inserted else {
            return nil
        }

        return begin(phase)
    }

    public static func end(_ token: Token?, metadata: String? = nil) {
        guard let token else {
            return
        }

        let duration = milliseconds(from: token.startedAt, to: DispatchTime.now())
        log(phase: token.phase, durationMilliseconds: duration, metadata: metadata)
    }

    public static func measure<T>(
        _ phase: String,
        metadata: (T) -> String? = { _ in nil },
        _ operation: () throws -> T
    ) rethrows -> T {
        let token = begin(phase)
        do {
            let value = try operation()
            end(token, metadata: metadata(value))
            return value
        } catch {
            end(token, metadata: "failed=true")
            throw error
        }
    }

    public static func metadata(for image: NSImage?, filename: String? = nil, byteCount: Int64? = nil) -> String {
        [
            filename.map { "filename=\($0)" },
            byteCount.map { "bytes=\($0)" },
            image.map { "imagePoints=\(format(Double($0.size.width)))x\(format(Double($0.size.height)))" }
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private static func log(phase: String, durationMilliseconds: Double?, metadata: String?) {
        let elapsed = milliseconds(from: appStartedAt, to: DispatchTime.now())
        let durationText = durationMilliseconds.map { " durationMs=\(format($0))" } ?? ""
        let metadataText = metadata.map { " \($0)" } ?? ""
        logger.info("startup phase=\(phase, privacy: .public) elapsedMs=\(format(elapsed), privacy: .public)\(durationText, privacy: .public)\(metadataText, privacy: .public)")
    }

    private static func milliseconds(from start: DispatchTime, to end: DispatchTime) -> Double {
        Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
#endif
