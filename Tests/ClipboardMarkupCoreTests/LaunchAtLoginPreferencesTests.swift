@testable import ClipboardMarkupCore
import XCTest

@MainActor
final class LaunchAtLoginPreferencesTests: XCTestCase {
    func testStatusMapping() {
        XCTAssertEqual(LaunchAtLoginPreferences.launchAtLoginStatus(for: .notRegistered), .off)
        XCTAssertEqual(LaunchAtLoginPreferences.launchAtLoginStatus(for: .enabled), .enabled)
        XCTAssertEqual(LaunchAtLoginPreferences.launchAtLoginStatus(for: .requiresApproval), .requiresApproval)
        XCTAssertEqual(LaunchAtLoginPreferences.launchAtLoginStatus(for: .notFound), .unavailable)
        XCTAssertEqual(LaunchAtLoginPreferences.launchAtLoginStatus(for: .unknown), .unavailable)
    }

    func testToggleOnRegistersAndRefreshesStatus() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let preferences = LaunchAtLoginPreferences(service: service)

        preferences.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(preferences.status, .enabled)
    }

    func testToggleOffUnregistersAndRefreshesStatus() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        let preferences = LaunchAtLoginPreferences(service: service)

        preferences.setLaunchAtLoginEnabled(false)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(preferences.status, .off)
    }

    func testToggleOffTreatsAlreadyNotRegisteredAsOff() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        service.unregisterError = FakeLaunchAtLoginError.alreadyNotRegistered
        service.statusAfterUnregisterError = .notRegistered
        let preferences = LaunchAtLoginPreferences(service: service)

        preferences.setLaunchAtLoginEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(preferences.status, .off)
    }

    func testRequiresApprovalExposesSystemSettingsAction() {
        let service = FakeLaunchAtLoginService(status: .requiresApproval)
        let preferences = LaunchAtLoginPreferences(service: service)

        XCTAssertEqual(preferences.status, .requiresApproval)
        XCTAssertTrue(preferences.status.canOpenSystemSettings)

        preferences.openSystemSettingsLoginItems()

        XCTAssertEqual(service.openSystemSettingsCallCount, 1)
    }

    func testRegisterErrorIsPresented() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.registerError = FakeLaunchAtLoginError.denied
        let preferences = LaunchAtLoginPreferences(service: service)

        preferences.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(preferences.status, .error("Denied"))
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    private(set) var serviceStatus: LaunchAtLoginServiceStatus
    var registerError: Error?
    var unregisterError: Error?
    var statusAfterUnregisterError: LaunchAtLoginServiceStatus?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var openSystemSettingsCallCount = 0

    init(status: LaunchAtLoginServiceStatus) {
        self.serviceStatus = status
    }

    var status: LaunchAtLoginServiceStatus {
        serviceStatus
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        serviceStatus = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            if let statusAfterUnregisterError {
                serviceStatus = statusAfterUnregisterError
            }
            throw unregisterError
        }
        serviceStatus = .notRegistered
    }

    func openSystemSettingsLoginItems() {
        openSystemSettingsCallCount += 1
    }
}

private enum FakeLaunchAtLoginError: LocalizedError {
    case denied
    case alreadyNotRegistered

    var errorDescription: String? {
        switch self {
        case .denied:
            "Denied"
        case .alreadyNotRegistered:
            "Already not registered"
        }
    }
}
