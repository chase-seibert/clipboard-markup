import AppKit
import Combine
import ClipboardMarkupCore
import SwiftUI

@main
struct ClipboardMarkupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @FocusedValue(\.clipboardCommandContext) private var focusedCommandContext

    @StateObject private var store = ClipboardStore()
    @StateObject private var commandRelay = AppCommandRelay()
    @StateObject private var shortcutPreferences = ShortcutPreferences()
    @StateObject private var appearancePreferences = AppearancePreferences()
    @StateObject private var libraryPreferences = LibraryPreferences()
    @StateObject private var storageLocationPreferences = StorageLocationPreferences()
    @StateObject private var analyticsPreferences: AnalyticsPreferences
    @StateObject private var analyticsRecorder: AnalyticsRecorder

    init() {
        let analyticsPreferences = AnalyticsPreferences()
        _analyticsPreferences = StateObject(wrappedValue: analyticsPreferences)
        _analyticsRecorder = StateObject(wrappedValue: AnalyticsRecorder(preferences: analyticsPreferences))
    }

    var body: some Scene {
        WindowGroup("Clipboard Markup", id: "main") {
            ClipboardRootView(
                store: store,
                commandRelay: commandRelay,
                libraryPreferences: libraryPreferences,
                analyticsRecorder: analyticsRecorder
            )
                .environment(\.appFontScale, appearancePreferences.fontScale)
                .environment(\.appThumbnailSize, CGFloat(appearancePreferences.thumbnailSize))
                .preferredColorScheme(appearancePreferences.colorSchemePreference.colorScheme)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear {
                    #if DEBUG
                    StartupTimingLogger.markOnce(.mainWindowAppear, "main window appeared")
                    #endif
                    store.analyticsRecorder = analyticsRecorder
                    analyticsRecorder.start()
                    analyticsRecorder.record(.appWindowOpened)
                    appDelegate.configure(
                        store: store,
                        commandRelay: commandRelay,
                        shortcutPreferences: shortcutPreferences,
                        appearancePreferences: appearancePreferences
                    )
                }
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Export Selected Clip...") {
                    exportSelectedClip()
                }
                .disabled(!commandState.canExport)
            }
            CommandGroup(replacing: .help) {
                Button("Clipboard Markup Help") {
                    HelpService.openHelp()
                }
            }
            CommandMenu("Library") {
                ForEach(LibraryFilter.allCases) { filter in
                    Button(filter.title) {
                        commandRelay.showMainWindow()
                        libraryPreferences.setFilter(filter)
                    }
                    .keyboardShortcut(KeyEquivalent(filter.keyboardShortcutKey), modifiers: [.command])
                }
            }
            CommandMenu("Clip") {
                Button("Copy") {
                    copySelectedClip()
                }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(!commandState.canCopy)

                Button(alternateCopyTitle) {
                    copyAlternateSelectedClip()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(!canAlternateCopy)

                Divider()

                Button("Markup") {
                    markupSelectedClip()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(!commandState.canMarkup)

                Button("Quick Look") {
                    quickLookSelectedClip()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!commandState.canQuickLook)

                Divider()

                Button("Rename (⌘↩)") {
                    renameSelectedClip()
                }
                .disabled(!commandState.canRename)

                Button(favoriteTitle) {
                    toggleFavoriteSelectedClip()
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(!commandState.canToggleFavorite)

                if selectedItem?.isDeleted == true {
                    Button("Restore") {
                        restoreSelectedClip()
                    }
                    .disabled(!commandState.canRestore)
                } else {
                    Button("Delete (⌫)") {
                        deleteSelectedClip()
                    }
                    .disabled(!commandState.canDelete)
                }

                Divider()

                Button("Share...") {
                    shareSelectedClip()
                }
                .disabled(!commandState.canShare)
            }
            CommandGroup(before: .textEditing) {
                Divider()

                Button("Find Clips") {
                    commandRelay.showSearch()
                }
                .keyboardShortcut("f", modifiers: [.command])
            }

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
            SettingsView(
                shortcutPreferences: shortcutPreferences,
                appearancePreferences: appearancePreferences,
                store: store,
                libraryPreferences: libraryPreferences,
                storageLocationPreferences: storageLocationPreferences,
                analyticsPreferences: analyticsPreferences,
                analyticsRecorder: analyticsRecorder
            )
                .environment(\.appFontScale, appearancePreferences.fontScale)
                .preferredColorScheme(appearancePreferences.colorSchemePreference.colorScheme)
        }

        MenuBarExtra("Clipboard Markup", systemImage: "doc.on.clipboard") {
            ClipboardMenuBarExtraContent(
                store: store,
                commandRelay: commandRelay,
                libraryPreferences: libraryPreferences,
                analyticsRecorder: analyticsRecorder
            )
                .environment(\.appFontScale, appearancePreferences.fontScale)
                .preferredColorScheme(appearancePreferences.colorSchemePreference.colorScheme)
        }
        .menuBarExtraStyle(.window)
    }

    private var selectedItem: ClipboardItem? {
        focusedCommandContext?.item ?? store.item(id: libraryPreferences.selectedItemID)
    }

    private var commandState: ClipboardCommandState {
        focusedCommandContext?.state ?? ClipboardCommandState(item: selectedItem)
    }

    private var canAlternateCopy: Bool {
        commandState.canCopyPlainText || commandState.canCopyOriginalImage
    }

    private var alternateCopyTitle: String {
        guard let selectedItem else {
            return "Copy Alternate"
        }

        switch selectedItem.kind {
        case .text:
            return "Copy Plain Text"
        case .image:
            return "Copy Original Image"
        }
    }

    private var favoriteTitle: String {
        selectedItem?.isSaved == true ? "Remove from Favorites" : "Add to Favorites"
    }

    private func copySelectedClip() {
        if let focusedCommandContext {
            focusedCommandContext.copy()
            return
        }

        guard let selectedItem else {
            return
        }
        store.copyPreferred(itemID: selectedItem.id)
    }

    private func copyAlternateSelectedClip() {
        if let focusedCommandContext {
            focusedCommandContext.copyAlternate()
            return
        }

        guard let selectedItem else {
            return
        }
        switch selectedItem.kind {
        case .text:
            store.copyText(itemID: selectedItem.id, variant: .plain)
        case .image:
            store.copyImage(itemID: selectedItem.id, variant: .original)
        }
    }

    private func markupSelectedClip() {
        if let focusedCommandContext {
            focusedCommandContext.markup()
        } else {
            commandRelay.markupSelectedClip()
        }
    }

    private func quickLookSelectedClip() {
        if let focusedCommandContext {
            focusedCommandContext.quickLook()
            return
        }

        selectedItem.map { store.quickLook(itemID: $0.id, variant: .preferred) }
    }

    private func renameSelectedClip() {
        if let focusedCommandContext {
            focusedCommandContext.rename()
        } else {
            commandRelay.renameSelectedClip()
        }
    }

    private func toggleFavoriteSelectedClip() {
        if let focusedCommandContext {
            focusedCommandContext.toggleFavorite()
            return
        }

        guard let selectedItem else {
            return
        }
        store.toggleSaved(itemID: selectedItem.id)
    }

    private func deleteSelectedClip() {
        if let focusedCommandContext {
            focusedCommandContext.delete()
        } else {
            selectedItem.map { store.delete(itemID: $0.id) }
        }
    }

    private func restoreSelectedClip() {
        if let focusedCommandContext {
            focusedCommandContext.restore()
        } else {
            selectedItem.map { store.restore(itemID: $0.id) }
        }
    }

    private func exportSelectedClip() {
        guard let selectedItem,
              let defaultPlan = store.defaultExportPlan(itemID: selectedItem.id)
        else {
            return
        }

        let formats = store.availableExportFormats(itemID: selectedItem.id)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultPlan.suggestedFilename
        panel.allowedContentTypes = [defaultPlan.contentType]

        let formatPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        let accessoryController = ExportFormatAccessoryController(
            panel: panel,
            item: selectedItem,
            formats: formats,
            titleProvider: exportFormatTitle
        )
        if formats.count > 1 {
            for format in formats {
                formatPopup.addItem(withTitle: exportFormatTitle(format, for: selectedItem))
            }
            formatPopup.target = accessoryController
            formatPopup.action = #selector(ExportFormatAccessoryController.formatChanged(_:))
            let stack = NSStackView(views: [
                NSTextField(labelWithString: "Format:"),
                formatPopup
            ])
            stack.orientation = .horizontal
            stack.spacing = 8
            panel.accessoryView = stack
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        _ = accessoryController

        let format = formats.indices.contains(formatPopup.indexOfSelectedItem)
            ? formats[formatPopup.indexOfSelectedItem]
            : defaultPlan.format

        do {
            try store.writeExport(itemID: selectedItem.id, format: format, to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func shareSelectedClip() {
        guard let selectedItem,
              let contentView = NSApp.keyWindow?.contentView
        else {
            return
        }

        let items = store.sharingItems(itemID: selectedItem.id)
        guard !items.isEmpty else {
            return
        }

        NSSharingServicePicker(items: items).show(
            relativeTo: contentView.bounds,
            of: contentView,
            preferredEdge: .minY
        )
    }

    private func exportFormatTitle(_ format: ClipboardTransferFormat, for item: ClipboardItem) -> String {
        switch format {
        case .plainText:
            "Plain Text (.txt)"
        case .richText:
            "Rich Text (.rtf)"
        case .preferredImage:
            item.hasMarkedImage ? "Marked Image (.png)" : "Image (.png)"
        case .originalImage:
            "Original Image (.png)"
        }
    }
}

private extension AppColorSchemePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

@MainActor
private enum AppAppearanceApplier {
    static func apply(_ preference: AppColorSchemePreference) {
        // AppKit-owned surfaces such as menu bar extra windows inherit NSApp.appearance.
        switch preference {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
private final class ExportFormatAccessoryController: NSObject {
    private weak var panel: NSSavePanel?
    private let item: ClipboardItem
    private let formats: [ClipboardTransferFormat]
    private let titleProvider: (ClipboardTransferFormat, ClipboardItem) -> String

    init(
        panel: NSSavePanel,
        item: ClipboardItem,
        formats: [ClipboardTransferFormat],
        titleProvider: @escaping (ClipboardTransferFormat, ClipboardItem) -> String
    ) {
        self.panel = panel
        self.item = item
        self.formats = formats
        self.titleProvider = titleProvider
    }

    @objc func formatChanged(_ sender: NSPopUpButton) {
        guard formats.indices.contains(sender.indexOfSelectedItem) else {
            return
        }

        let selectedFormat = formats[sender.indexOfSelectedItem]
        let plan = ClipboardTransferPlanner.exportPlan(for: item, format: selectedFormat)
        panel?.nameFieldStringValue = plan.suggestedFilename
        panel?.allowedContentTypes = [plan.contentType]
        sender.toolTip = titleProvider(selectedFormat, item)
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shortcutManager: GlobalShortcutManager?
    private var shortcutCancellable: AnyCancellable?
    private var appearanceCancellable: AnyCancellable?
    private var didConfigure = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        #if DEBUG
        StartupTimingLogger.mark("application did finish launching")
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func configure(
        store: ClipboardStore,
        commandRelay: AppCommandRelay,
        shortcutPreferences: ShortcutPreferences,
        appearancePreferences: AppearancePreferences
    ) {
        AppAppearanceApplier.apply(appearancePreferences.colorSchemePreference)

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

        appearanceCancellable = appearancePreferences.$colorSchemePreference
            .dropFirst()
            .sink { preference in
                Task { @MainActor in
                    AppAppearanceApplier.apply(preference)
                }
            }
    }
}
