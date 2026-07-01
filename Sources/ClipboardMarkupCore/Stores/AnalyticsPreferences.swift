import Combine
import Foundation

@MainActor
public final class AnalyticsPreferences: ObservableObject {
    @Published public private(set) var isSharingEnabled: Bool
    @Published public private(set) var redirectBaseURLString: String?
    @Published public private(set) var isStoppedByServer: Bool

    public let installID: String

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isSharingEnabled = Self.loadSharingEnabled(from: userDefaults)
        self.installID = Self.loadInstallID(from: userDefaults)
        self.redirectBaseURLString = userDefaults.string(forKey: Keys.redirectBaseURLString)
        self.isStoppedByServer = userDefaults.bool(forKey: Keys.isStoppedByServer)
    }

    public var redirectBaseURL: URL? {
        guard let redirectBaseURLString else {
            return nil
        }
        return URL(string: redirectBaseURLString)
    }

    public func setSharingEnabled(_ isSharingEnabled: Bool) {
        self.isSharingEnabled = isSharingEnabled
        userDefaults.set(isSharingEnabled, forKey: Keys.isSharingEnabled)
    }

    public func setRedirectBaseURL(_ url: URL?) {
        redirectBaseURLString = url?.absoluteString
        if let url {
            userDefaults.set(url.absoluteString, forKey: Keys.redirectBaseURLString)
        } else {
            userDefaults.removeObject(forKey: Keys.redirectBaseURLString)
        }
    }

    public func setStoppedByServer(_ isStoppedByServer: Bool) {
        self.isStoppedByServer = isStoppedByServer
        userDefaults.set(isStoppedByServer, forKey: Keys.isStoppedByServer)
    }

    public func resetServerControls() {
        setRedirectBaseURL(nil)
        setStoppedByServer(false)
    }

    private static func loadSharingEnabled(from userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: Keys.isSharingEnabled) != nil else {
            return true
        }
        return userDefaults.bool(forKey: Keys.isSharingEnabled)
    }

    private static func loadInstallID(from userDefaults: UserDefaults) -> String {
        if let installID = userDefaults.string(forKey: Keys.installID), !installID.isEmpty {
            return installID
        }

        let installID = UUID().uuidString
        userDefaults.set(installID, forKey: Keys.installID)
        return installID
    }

    private enum Keys {
        static let isSharingEnabled = "analytics.isSharingEnabled"
        static let installID = "analytics.installID"
        static let redirectBaseURLString = "analytics.redirectBaseURLString"
        static let isStoppedByServer = "analytics.isStoppedByServer"
    }
}
