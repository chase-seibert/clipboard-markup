import AppKit
import Carbon
import Foundation

public struct KeyboardShortcutPreference: Equatable, Hashable, Codable, Identifiable {
    public var id: String { "\(keyCode)-\(modifiers)" }

    public var keyCode: UInt32
    public var modifiers: UInt32
    public var displayLabel: String

    public init(keyCode: UInt32, modifiers: UInt32, displayLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayLabel = displayLabel
    }

    public static let defaultShortcut = KeyboardShortcutPreference(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: UInt32(controlKey) | UInt32(optionKey),
        displayLabel: "⌃⌥C"
    )

    public static let presets = [
        KeyboardShortcutPreference.defaultShortcut,
        KeyboardShortcutPreference(
            keyCode: UInt32(kVK_ANSI_M),
            modifiers: UInt32(controlKey) | UInt32(optionKey),
            displayLabel: "⌃⌥M"
        ),
        KeyboardShortcutPreference(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey),
            displayLabel: "⌥Space"
        )
    ]

    static func from(event: NSEvent) -> KeyboardShortcutPreference? {
        let relevantModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !relevantModifiers.isEmpty,
              let keyLabel = keyLabel(for: UInt32(event.keyCode), characters: event.charactersIgnoringModifiers)
        else {
            return nil
        }

        let modifiers = carbonModifiers(from: relevantModifiers)
        return KeyboardShortcutPreference(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            displayLabel: displayLabel(keyLabel: keyLabel, modifiers: modifiers)
        )
    }

    static func displayLabel(keyLabel: String, modifiers: UInt32) -> String {
        "\(modifierGlyphs(for: modifiers))\(keyLabel)"
    }

    public static func modifierGlyphs(for modifiers: UInt32) -> String {
        var glyphs = ""
        if modifiers & UInt32(controlKey) != 0 {
            glyphs += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            glyphs += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            glyphs += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            glyphs += "⌘"
        }
        return glyphs
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        return modifiers
    }

    private static func keyLabel(for keyCode: UInt32, characters: String?) -> String? {
        switch Int(keyCode) {
        case kVK_Space:
            return "Space"
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Delete:
            return "Delete"
        case kVK_ForwardDelete:
            return "Delete"
        case kVK_LeftArrow:
            return "←"
        case kVK_RightArrow:
            return "→"
        case kVK_UpArrow:
            return "↑"
        case kVK_DownArrow:
            return "↓"
        case kVK_Escape:
            return nil
        default:
            guard let character = characters?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !character.isEmpty
            else {
                return nil
            }
            return character.uppercased()
        }
    }
}
