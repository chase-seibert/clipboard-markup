import AppKit
import Combine
import ClipboardMarkupCore
import SwiftUI

@main
struct ClipboardMarkupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var store = ClipboardStore()
    @StateObject private var commandRelay = AppCommandRelay()
    @StateObject private var shortcutPreferences = ShortcutPreferences()
    @StateObject private var appearancePreferences = AppearancePreferences()
    @StateObject private var libraryPreferences = LibraryPreferences()

    var body: some Scene {
        WindowGroup("Clipboard Markup", id: "main") {
            ClipboardRootView(
                store: store,
                commandRelay: commandRelay,
                libraryPreferences: libraryPreferences
            )
                .environment(\.appFontScale, appearancePreferences.fontScale)
                .environment(\.appThumbnailSize, CGFloat(appearancePreferences.thumbnailSize))
                .frame(minWidth: 980, minHeight: 640)
                .onAppear {
                    appDelegate.configure(
                        store: store,
                        commandRelay: commandRelay,
                        shortcutPreferences: shortcutPreferences
                    )
                }
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .sidebar) {
                Divider()

                Button("Increase Text Size") {
                    appearancePreferences.increaseFontScale()
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Decrease Text Size") {
                    appearancePreferences.decreaseFontScale()
                }
                .keyboardShortcut("-", modifiers: [.command])

                Button("Reset Text Size") {
                    appearancePreferences.resetFontScale()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(shortcutPreferences: shortcutPreferences, appearancePreferences: appearancePreferences)
                .environment(\.appFontScale, appearancePreferences.fontScale)
        }

        MenuBarExtra("Clipboard Markup", systemImage: "doc.on.clipboard") {
            ClipboardMenuBarExtraContent(store: store, commandRelay: commandRelay)
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shortcutManager: GlobalShortcutManager?
    private var shortcutCancellable: AnyCancellable?
    private var didConfigure = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func configure(
        store: ClipboardStore,
        commandRelay: AppCommandRelay,
        shortcutPreferences: ShortcutPreferences
    ) {
        guard !didConfigure else {
            return
        }

        didConfigure = true
        store.startMonitoring()
        shortcutManager = GlobalShortcutManager(shortcut: shortcutPreferences.shortcut) { [weak commandRelay] in
            commandRelay?.showMainWindow()
        }
        shortcutPreferences.setRegistrationStatus(shortcutManager?.isRegistered ?? false)

        shortcutCancellable = shortcutPreferences.$shortcut
            .dropFirst()
            .sink { [weak self, weak shortcutPreferences] shortcut in
                let isRegistered = self?.shortcutManager?.update(shortcut: shortcut) ?? false
                shortcutPreferences?.setRegistrationStatus(isRegistered)
            }
    }
}
