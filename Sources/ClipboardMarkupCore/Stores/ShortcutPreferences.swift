import Combine
import Foundation

@MainActor
public final class ShortcutPreferences: ObservableObject {
    @Published public private(set) var shortcut: KeyboardShortcutPreference
    @Published public private(set) var isRegistered = false

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.shortcut = Self.loadShortcut(from: userDefaults)
    }

    public func setShortcut(_ shortcut: KeyboardShortcutPreference) {
        self.shortcut = shortcut
        save(shortcut)
    }

    public func resetToDefault() {
        setShortcut(.defaultShortcut)
    }

    public func setRegistrationStatus(_ isRegistered: Bool) {
        self.isRegistered = isRegistered
    }

    private func save(_ shortcut: KeyboardShortcutPreference) {
        userDefaults.set(Int(shortcut.keyCode), forKey: Keys.keyCode)
        userDefaults.set(Int(shortcut.modifiers), forKey: Keys.modifiers)
        userDefaults.set(shortcut.displayLabel, forKey: Keys.displayLabel)
    }

    private static func loadShortcut(from userDefaults: UserDefaults) -> KeyboardShortcutPreference {
        guard userDefaults.object(forKey: Keys.keyCode) != nil,
              userDefaults.object(forKey: Keys.modifiers) != nil,
              let displayLabel = userDefaults.string(forKey: Keys.displayLabel)
        else {
            return .defaultShortcut
        }

        return KeyboardShortcutPreference(
            keyCode: UInt32(userDefaults.integer(forKey: Keys.keyCode)),
            modifiers: UInt32(userDefaults.integer(forKey: Keys.modifiers)),
            displayLabel: displayLabel
        )
    }

    private enum Keys {
        static let keyCode = "globalShortcut.keyCode"
        static let modifiers = "globalShortcut.modifiers"
        static let displayLabel = "globalShortcut.displayLabel"
    }
}
