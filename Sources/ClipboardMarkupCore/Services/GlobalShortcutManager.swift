import Carbon
import Foundation

public final class GlobalShortcutManager {
    public static let defaultShortcutDescription = "Control-Option-C"

    private static let signature = fourCharacterCode("CLIP")
    private static var action: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var currentShortcut: KeyboardShortcutPreference?

    public private(set) var isRegistered = false

    public init(shortcut: KeyboardShortcutPreference = .defaultShortcut, action: @escaping () -> Void) {
        Self.action = action
        update(shortcut: shortcut)
    }

    deinit {
        unregister()
    }

    @discardableResult
    public func update(shortcut: KeyboardShortcutPreference) -> Bool {
        unregister()
        currentShortcut = shortcut
        register(shortcut: shortcut)
        return isRegistered
    }

    private func register(shortcut: KeyboardShortcutPreference) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr,
                      hotKeyID.signature == GlobalShortcutManager.signature,
                      hotKeyID.id == 1
                else {
                    return OSStatus(eventNotHandledErr)
                }

                DispatchQueue.main.async {
                    GlobalShortcutManager.action?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            return
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        isRegistered = registerStatus == noErr
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        hotKeyRef = nil
        eventHandlerRef = nil
        isRegistered = false
    }
}

private func fourCharacterCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
