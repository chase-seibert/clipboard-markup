import Foundation

public enum AnalyticsAudience: String, Codable, CaseIterable {
    case debug
    case test
    case beta
    case production
}

public struct AnalyticsConfiguration: Equatable {
    public let analyticsBaseURL: URL
    public let namespace: String
    public let appName: String
    public let appVersion: String
    public let appPlatform: String
    public let audience: AnalyticsAudience
    public let analyticsKeyID: String
    public let analyticsSecret: String

    public init(
        analyticsBaseURL: URL,
        appName: String = "clipboard-markup",
        appVersion: String,
        appPlatform: String = "macOS",
        audience: AnalyticsAudience,
        analyticsKeyID: String,
        analyticsSecret: String
    ) throws {
        let normalizedBaseURL = Self.normalizedBaseURL(analyticsBaseURL)
        let namespace = normalizedBaseURL.lastPathComponent

        guard Self.isValidNamespace(namespace) else {
            throw AnalyticsConfigurationError.invalidNamespace(namespace)
        }
        guard normalizedBaseURL.scheme == "https" || normalizedBaseURL.scheme == "http" else {
            throw AnalyticsConfigurationError.invalidBaseURL
        }
        guard !analyticsKeyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyticsConfigurationError.missingKeyID
        }
        guard !analyticsSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyticsConfigurationError.missingSecret
        }

        self.analyticsBaseURL = normalizedBaseURL
        self.namespace = namespace
        self.appName = appName
        self.appVersion = appVersion
        self.appPlatform = appPlatform
        self.audience = audience
        self.analyticsKeyID = analyticsKeyID
        self.analyticsSecret = analyticsSecret
    }

    public var uploadURL: URL {
        analyticsBaseURL
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("events")
    }

    public func replacingBaseURL(_ baseURL: URL) throws -> AnalyticsConfiguration {
        try AnalyticsConfiguration(
            analyticsBaseURL: baseURL,
            appName: appName,
            appVersion: appVersion,
            appPlatform: appPlatform,
            audience: audience,
            analyticsKeyID: analyticsKeyID,
            analyticsSecret: analyticsSecret
        )
    }

    public static func loadDefault(
        fileManager: FileManager = .default,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Result<AnalyticsConfiguration, AnalyticsConfigurationLoadError> {
        let appVersion = Self.bundleAppVersion(bundle: bundle)

        if let configuration = loadFromApplicationSupport(fileManager: fileManager, appVersion: appVersion) {
            return configuration
        }

        if let configuration = loadBundled(bundle: bundle, appVersion: appVersion) {
            return configuration
        }

        if let configuration = loadEnvironment(environment, appVersion: appVersion) {
            return configuration
        }

        return .failure(.missingConfiguration)
    }

    static func load(from url: URL, appVersion: String) -> Result<AnalyticsConfiguration, AnalyticsConfigurationLoadError> {
        do {
            let data = try Data(contentsOf: url)
            return decode(data: data, appVersion: appVersion)
        } catch {
            return .failure(.unreadableConfiguration(error.localizedDescription))
        }
    }

    static func decode(data: Data, appVersion: String) -> Result<AnalyticsConfiguration, AnalyticsConfigurationLoadError> {
        do {
            let file = try PropertyListDecoder().decode(AnalyticsConfigurationFile.self, from: data)
            guard let baseURL = URL(string: file.analyticsBaseUrl) else {
                return .failure(.invalidConfiguration(AnalyticsConfigurationError.invalidBaseURL.localizedDescription))
            }
            let audience = AnalyticsAudience(rawValue: file.audience) ?? .debug
            let configuration = try AnalyticsConfiguration(
                analyticsBaseURL: baseURL,
                appVersion: appVersion,
                audience: audience,
                analyticsKeyID: file.analyticsKeyId,
                analyticsSecret: file.analyticsSecret
            )
            return .success(configuration)
        } catch let error as AnalyticsConfigurationError {
            return .failure(.invalidConfiguration(error.localizedDescription))
        } catch {
            return .failure(.invalidConfiguration(error.localizedDescription))
        }
    }

    static func applicationSupportConfigURL(fileManager: FileManager = .default) -> URL {
        analyticsRootURL(fileManager: fileManager)
            .deletingLastPathComponent()
            .appendingPathComponent("AnalyticsConfig.plist")
    }

    static func analyticsRootURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return applicationSupport
            .appendingPathComponent("ClipboardMarkup", isDirectory: true)
            .appendingPathComponent("Analytics", isDirectory: true)
    }

    private static func loadFromApplicationSupport(
        fileManager: FileManager,
        appVersion: String
    ) -> Result<AnalyticsConfiguration, AnalyticsConfigurationLoadError>? {
        let url = applicationSupportConfigURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return load(from: url, appVersion: appVersion)
    }

    private static func loadBundled(
        bundle: Bundle,
        appVersion: String
    ) -> Result<AnalyticsConfiguration, AnalyticsConfigurationLoadError>? {
        guard let url = bundle.url(forResource: "AnalyticsConfig", withExtension: "plist") else {
            return nil
        }
        return load(from: url, appVersion: appVersion)
    }

    static func loadEnvironment(
        _ environment: [String: String],
        appVersion: String
    ) -> Result<AnalyticsConfiguration, AnalyticsConfigurationLoadError>? {
        guard let baseURLString = environment["CLIPBOARD_MARKUP_ANALYTICS_BASE_URL"],
              let keyID = environment["CLIPBOARD_MARKUP_ANALYTICS_KEY_ID"],
              let secret = environment["CLIPBOARD_MARKUP_ANALYTICS_SECRET"]
        else {
            return nil
        }

        guard let baseURL = URL(string: baseURLString) else {
            return .failure(.invalidConfiguration(AnalyticsConfigurationError.invalidBaseURL.localizedDescription))
        }

        let audience = environment["CLIPBOARD_MARKUP_ANALYTICS_AUDIENCE"]
            .flatMap(AnalyticsAudience.init(rawValue:)) ?? .debug

        do {
            return .success(
                try AnalyticsConfiguration(
                    analyticsBaseURL: baseURL,
                    appVersion: appVersion,
                    audience: audience,
                    analyticsKeyID: keyID,
                    analyticsSecret: secret
                )
            )
        } catch let error as AnalyticsConfigurationError {
            return .failure(.invalidConfiguration(error.localizedDescription))
        } catch {
            return .failure(.invalidConfiguration(error.localizedDescription))
        }
    }

    private static func bundleAppVersion(bundle: Bundle) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let version, !version.isEmpty {
            return version
        }
        if let build, !build.isEmpty {
            return build
        }
        return "0.0.0"
    }

    private static func normalizedBaseURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        return components.url ?? url
    }

    private static func isValidNamespace(_ namespace: String) -> Bool {
        guard !namespace.isEmpty, namespace.count <= 63 else {
            return false
        }

        let pattern = #"^[a-z0-9][a-z0-9-]{0,62}$"#
        return namespace.range(of: pattern, options: .regularExpression) != nil
    }
}

public enum AnalyticsConfigurationLoadError: LocalizedError, Equatable {
    case missingConfiguration
    case unreadableConfiguration(String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Analytics config is missing."
        case let .unreadableConfiguration(message):
            "Analytics config could not be read: \(message)"
        case let .invalidConfiguration(message):
            "Analytics config is invalid: \(message)"
        }
    }
}

enum AnalyticsConfigurationError: LocalizedError {
    case invalidBaseURL
    case invalidNamespace(String)
    case missingKeyID
    case missingSecret

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Base URL must be an HTTP or HTTPS URL."
        case let .invalidNamespace(namespace):
            "Namespace '\(namespace)' must be a lowercase slug in the base URL path."
        case .missingKeyID:
            "Analytics key id is required."
        case .missingSecret:
            "Analytics secret is required."
        }
    }
}

private struct AnalyticsConfigurationFile: Decodable {
    let analyticsBaseUrl: String
    let analyticsKeyId: String
    let analyticsSecret: String
    let audience: String
}
