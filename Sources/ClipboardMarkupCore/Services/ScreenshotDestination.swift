import Foundation

/// A hint from macOS preferences, not proof that the next capture reaches the clipboard.
/// Screenshot apps and customized shortcuts can override the saved destination.
enum ScreenshotDestination: Equatable {
    case clipboard
    case defaultFile
    case file
    case other
    case unknown

    static func read(preferencesURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences/com.apple.screencapture.plist")) -> Self {
        do {
            let data = try Data(contentsOf: preferencesURL)
            guard let preferences = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                return .unknown
            }
            guard let target = preferences["target"] else {
                return preferences["location"] == nil ? .defaultFile : .file
            }
            // These macOS preference keys are not a public API. Treat unrecognized
            // values conservatively and offer a real clipboard test in the UI.
            switch target as? String {
            case "clipboard": return .clipboard
            case "file": return .file
            case "preview", "mail", "messages": return .other
            default: return .unknown
            }
        } catch CocoaError.fileReadNoSuchFile {
            return .defaultFile
        } catch {
            return .unknown
        }
    }

    var message: String {
        switch self {
        case .clipboard: "macOS is set to copy screenshots to the clipboard."
        case .defaultFile: "macOS appears to use its default: save screenshots to the Desktop."
        case .file: "macOS appears to save screenshots to files."
        case .other: "macOS appears to send screenshots to another app."
        case .unknown: "We couldn’t determine your screenshot destination."
        }
    }
}
