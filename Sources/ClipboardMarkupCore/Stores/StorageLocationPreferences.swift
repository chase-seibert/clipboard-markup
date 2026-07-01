import Combine
import Foundation

public struct StorageLocationPreset: Identifiable, Hashable {
    public enum Identifier: String, Hashable {
        case applicationSupport
        case iCloudDrive
        case dropbox
        case googleDrive
        case custom
    }

    public let id: Identifier
    public let title: String
    public let subtitle: String
    public let url: URL
    public let systemImage: String
}

@MainActor
public final class StorageLocationPreferences: ObservableObject {
    @Published public private(set) var customRootPath: String?

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        #if DEBUG
        let initToken = StartupTimingLogger.beginOnce(.storagePreferencesInit, "storage preferences init")
        #endif
        self.userDefaults = userDefaults
        self.customRootPath = userDefaults.string(forKey: Keys.customRootPath)
        self.restoreSecurityScopedAccess()
        #if DEBUG
        StartupTimingLogger.end(initToken, metadata: "custom=\(customRootPath != nil)")
        #endif
    }

    public var rootURL: URL {
        guard let customRootPath, !customRootPath.isEmpty else {
            return Self.defaultRootURL()
        }

        return URL(fileURLWithPath: customRootPath, isDirectory: true).standardizedFileURL
    }

    public var isUsingDefaultLocation: Bool {
        customRootPath == nil
    }

    public static func defaultRootURL(fileManager: FileManager = .default) -> URL {
        ClipboardStorage.defaultRootURL(fileManager: fileManager).standardizedFileURL
    }

    public static func recommendedLocations(fileManager: FileManager = .default) -> [StorageLocationPreset] {
        [
            StorageLocationPreset(
                id: .applicationSupport,
                title: "Default",
                subtitle: "Local Application Support folder",
                url: defaultRootURL(fileManager: fileManager),
                systemImage: "internaldrive"
            ),
            StorageLocationPreset(
                id: .iCloudDrive,
                title: "iCloud Drive",
                subtitle: "Sync with Apple's iCloud Drive",
                url: iCloudDriveURL(fileManager: fileManager),
                systemImage: "icloud"
            ),
            StorageLocationPreset(
                id: .dropbox,
                title: "Dropbox",
                subtitle: "Sync through your Dropbox folder",
                url: dropboxURL(fileManager: fileManager),
                systemImage: "shippingbox"
            ),
            StorageLocationPreset(
                id: .googleDrive,
                title: "Google Drive",
                subtitle: "Sync through Google Drive",
                url: googleDriveURL(fileManager: fileManager),
                systemImage: "externaldrive"
            )
        ]
    }

    public static func sameLocation(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }

    public static func securityScopedBookmarkData(for rootURL: URL) -> Data? {
        try? rootURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public func setRootURL(_ rootURL: URL, bookmarkData: Data? = nil) {
        let standardizedURL = rootURL.standardizedFileURL
        if Self.sameLocation(standardizedURL, Self.defaultRootURL()) {
            resetToDefault()
            return
        }

        customRootPath = standardizedURL.path
        userDefaults.set(standardizedURL.path, forKey: Keys.customRootPath)
        if let bookmarkData {
            userDefaults.set(bookmarkData, forKey: Keys.bookmarkData)
        } else {
            userDefaults.removeObject(forKey: Keys.bookmarkData)
        }
    }

    public func resetToDefault() {
        customRootPath = nil
        userDefaults.removeObject(forKey: Keys.customRootPath)
        userDefaults.removeObject(forKey: Keys.bookmarkData)
    }

    private static func iCloudDriveURL(fileManager: FileManager) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
            .appendingPathComponent("ClipboardMarkup", isDirectory: true)
            .standardizedFileURL
    }

    private static func dropboxURL(fileManager: FileManager) -> URL {
        dropboxURL(
            fileManager: fileManager,
            homeDirectoryURL: fileManager.homeDirectoryForCurrentUser,
            memberNameCandidates: currentDropboxMemberNameCandidates()
        )
    }

    static func dropboxURL(
        fileManager: FileManager,
        homeDirectoryURL: URL,
        memberNameCandidates: [String]
    ) -> URL {
        let dropboxRoots = cloudStorageDirectories(
            prefix: "Dropbox",
            fileManager: fileManager,
            homeDirectoryURL: homeDirectoryURL
        )
        let teamRoot = dropboxRoots.first { !$0.lastPathComponent.localizedCaseInsensitiveContains("Personal") }
        if let teamRoot {
            let memberRoot = dropboxMemberDirectoryURL(
                in: teamRoot,
                memberNameCandidates: memberNameCandidates
            )
            return memberRoot
                .appendingPathComponent("ClipboardMarkup", isDirectory: true)
                .standardizedFileURL
        }

        if let personalRoot = dropboxRoots.first {
            return personalRoot
                .appendingPathComponent("ClipboardMarkup", isDirectory: true)
                .standardizedFileURL
        }

        return homeDirectoryURL
            .appendingPathComponent("Dropbox", isDirectory: true)
            .appendingPathComponent("ClipboardMarkup", isDirectory: true)
            .standardizedFileURL
    }

    private static func googleDriveURL(fileManager: FileManager) -> URL {
        let providerURL = cloudStorageDirectories(
            prefix: "GoogleDrive",
            fileManager: fileManager,
            homeDirectoryURL: fileManager.homeDirectoryForCurrentUser
        ).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/CloudStorage/GoogleDrive", isDirectory: true)

        return providerURL
            .appendingPathComponent("My Drive", isDirectory: true)
            .appendingPathComponent("ClipboardMarkup", isDirectory: true)
            .standardizedFileURL
    }

    private static func cloudStorageDirectories(
        prefix: String,
        fileManager: FileManager,
        homeDirectoryURL: URL
    ) -> [URL] {
        let cloudStorageURL = homeDirectoryURL
            .appendingPathComponent("Library/CloudStorage", isDirectory: true)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: cloudStorageURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return contents
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func dropboxMemberDirectoryURL(
        in teamRootURL: URL,
        memberNameCandidates: [String]
    ) -> URL {
        guard let memberName = preferredDropboxMemberName(from: memberNameCandidates) else {
            return teamRootURL
        }

        return teamRootURL.appendingPathComponent(memberName, isDirectory: true)
    }

    private static func currentDropboxMemberNameCandidates() -> [String] {
        [
            NSFullUserName(),
            NSUserName()
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }

    private static func preferredDropboxMemberName(from candidates: [String]) -> String? {
        candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func restoreSecurityScopedAccess() {
        guard let bookmarkData = userDefaults.data(forKey: Keys.bookmarkData) else {
            return
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            userDefaults.removeObject(forKey: Keys.bookmarkData)
            return
        }

        _ = url.startAccessingSecurityScopedResource()
        customRootPath = url.standardizedFileURL.path
        userDefaults.set(url.standardizedFileURL.path, forKey: Keys.customRootPath)

        if isStale, let refreshedBookmarkData = Self.securityScopedBookmarkData(for: url) {
            userDefaults.set(refreshedBookmarkData, forKey: Keys.bookmarkData)
        }
    }

    private enum Keys {
        static let customRootPath = "storage.customRootPath"
        static let bookmarkData = "storage.bookmarkData"
    }
}
