import Foundation

enum DeveloperMode {
    private static let userDefaultsKey = "ClipboardMarkupDeveloperModeEnabled"
    private static let environmentKey = "CLIPBOARD_MARKUP_DEVELOPER_MODE"

    static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        if UserDefaults.standard.bool(forKey: userDefaultsKey) {
            return true
        }

        let value = ProcessInfo.processInfo.environment[environmentKey]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
        #endif
    }
}
