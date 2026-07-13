import Combine
import Foundation
import ServiceManagement

public enum LaunchAtLoginStatus: Equatable {
    case off
    case enabled
    case requiresApproval
    case unavailable
    case error(String)

    public var isOn: Bool {
        switch self {
        case .enabled, .requiresApproval:
            true
        case .off, .unavailable, .error:
            false
        }
    }

    public var canOpenSystemSettings: Bool {
        self == .requiresApproval
    }

    public var displayText: String {
        switch self {
        case .off:
            "Clipboard Markup will not launch automatically."
        case .enabled:
            "Clipboard Markup will start quietly after you sign in."
        case .requiresApproval:
            "macOS needs approval in Login Items before automatic launch is allowed."
        case .unavailable:
            "Launch at login is unavailable for this app build."
        case let .error(message):
            message
        }
    }
}

enum LaunchAtLoginServiceStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown
}

@MainActor
protocol LaunchAtLoginServicing {
    var status: LaunchAtLoginServiceStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

@MainActor
public final class LaunchAtLoginPreferences: ObservableObject {
    public static let loginItemIdentifier = "com.chaseseibert.ClipboardMarkup.LoginLauncher"

    @Published public private(set) var status: LaunchAtLoginStatus

    private let service: LaunchAtLoginServicing

    public convenience init() {
        self.init(service: SMAppServiceLaunchAtLoginService(identifier: Self.loginItemIdentifier))
    }

    init(service: LaunchAtLoginServicing) {
        self.service = service
        self.status = Self.launchAtLoginStatus(for: service.status)
    }

    public func refresh() {
        status = Self.launchAtLoginStatus(for: service.status)
    }

    public func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try service.register()
            } else {
                try service.unregister()
            }
            refresh()
        } catch {
            if !isEnabled, service.status == .notRegistered {
                status = .off
            } else {
                status = .error(error.localizedDescription)
            }
        }
    }

    public func openSystemSettingsLoginItems() {
        service.openSystemSettingsLoginItems()
    }

    static func launchAtLoginStatus(for serviceStatus: LaunchAtLoginServiceStatus) -> LaunchAtLoginStatus {
        switch serviceStatus {
        case .notRegistered:
            .off
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound, .unknown:
            .unavailable
        }
    }
}

@MainActor
private final class SMAppServiceLaunchAtLoginService: LaunchAtLoginServicing {
    private let service: SMAppService

    init(identifier: String) {
        self.service = SMAppService.loginItem(identifier: identifier)
    }

    var status: LaunchAtLoginServiceStatus {
        switch service.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .notFound
        @unknown default:
            .unknown
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
