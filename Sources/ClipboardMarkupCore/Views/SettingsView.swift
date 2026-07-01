import AppKit
import Carbon
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var shortcutPreferences: ShortcutPreferences
    @ObservedObject private var appearancePreferences: AppearancePreferences
    @ObservedObject private var store: ClipboardStore
    @ObservedObject private var libraryPreferences: LibraryPreferences
    @ObservedObject private var storageLocationPreferences: StorageLocationPreferences
    @State private var isRecordingShortcut = false

    public init(
        shortcutPreferences: ShortcutPreferences,
        appearancePreferences: AppearancePreferences,
        store: ClipboardStore,
        libraryPreferences: LibraryPreferences,
        storageLocationPreferences: StorageLocationPreferences
    ) {
        self.shortcutPreferences = shortcutPreferences
        self.appearancePreferences = appearancePreferences
        self.store = store
        self.libraryPreferences = libraryPreferences
        self.storageLocationPreferences = storageLocationPreferences
    }

    public var body: some View {
        TabView {
            appearanceForm
                .tabItem {
                    Label("Appearance", systemImage: "textformat.size")
                }

            shortcutForm
                .tabItem {
                    Label("Shortcut", systemImage: "keyboard")
                }

            StorageLocationSettingsView(
                store: store,
                storageLocationPreferences: storageLocationPreferences
            )
                .tabItem {
                    Label("Storage Location", systemImage: "folder")
                }

            OtherSettingsView(
                store: store,
                libraryPreferences: libraryPreferences,
                storageLocationPreferences: storageLocationPreferences
            )
                .tabItem {
                    Label("Other", systemImage: "ellipsis.circle")
                }
        }
        .tint(.blue)
        .padding(18)
        .frame(width: 700, height: 540)
        .onExitCommand(perform: closeSettingsWindow)
    }

    private var appearanceForm: some View {
        Form {
            Section {
                HStack {
                    Text("Text size")
                        .appFont(size: 13)
                    Spacer()
                    Text(appearancePreferences.percentageLabel)
                        .appFont(size: 12, weight: .medium, design: .monospaced)
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { appearancePreferences.fontScale },
                        set: { appearancePreferences.setFontScale($0) }
                    ),
                    in: AppearancePreferences.minimumFontScale...AppearancePreferences.maximumFontScale,
                    step: AppearancePreferences.fontScaleStep
                )

                HStack {
                    Text("Use Command-plus and Command-minus to adjust app text.")
                        .appFont(size: 12)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Reset") {
                        appearancePreferences.resetFontScale()
                    }
                    .controlSize(.small)
                }

                Divider()

                HStack {
                    Text("Thumbnail size")
                        .appFont(size: 13)
                    Spacer()
                    Text(appearancePreferences.thumbnailSizeLabel)
                        .appFont(size: 12, weight: .medium, design: .monospaced)
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { appearancePreferences.thumbnailSize },
                        set: { appearancePreferences.setThumbnailSize($0) }
                    ),
                    in: AppearancePreferences.minimumThumbnailSize...AppearancePreferences.maximumThumbnailSize,
                    step: AppearancePreferences.thumbnailSizeStep
                )

                HStack {
                    Spacer()

                    Button("Reset") {
                        appearancePreferences.resetThumbnailSize()
                    }
                    .controlSize(.small)
                }
            } header: {
                Text("Appearance")
                    .appFont(size: 12, weight: .semibold)
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutForm: some View {
        Form {
            Section {
                HStack {
                    Text("Open Clipboard Markup")
                        .appFont(size: 13)
                    Spacer()
                    ShortcutRecorder(
                        shortcut: Binding(
                            get: { shortcutPreferences.shortcut },
                            set: { shortcutPreferences.setShortcut($0) }
                        ),
                        isRecording: $isRecordingShortcut
                    )
                    .frame(width: 150, height: 28)
                }

                Picker("Suggested shortcuts", selection: presetBinding) {
                    ForEach(KeyboardShortcutPreference.presets) { shortcut in
                        Text(shortcut.displayLabel)
                            .appFont(size: 13)
                            .tag(shortcut)
                    }
                }

                HStack {
                    Label(
                        shortcutPreferences.isRegistered ? "Registered" : "Not registered",
                        systemImage: shortcutPreferences.isRegistered ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                        .appFont(size: 12)
                        .foregroundStyle(shortcutPreferences.isRegistered ? Color.green : Color.red)

                    Spacer()

                    Button("Reset") {
                        shortcutPreferences.resetToDefault()
                    }
                    .controlSize(.small)
                }
            } header: {
                Text("Global Shortcut")
                    .appFont(size: 12, weight: .semibold)
            }
        }
        .formStyle(.grouped)
    }

    private var presetBinding: Binding<KeyboardShortcutPreference> {
        Binding(
            get: {
                KeyboardShortcutPreference.presets.contains(shortcutPreferences.shortcut)
                    ? shortcutPreferences.shortcut
                    : KeyboardShortcutPreference.defaultShortcut
            },
            set: { shortcutPreferences.setShortcut($0) }
        )
    }

    private func closeSettingsWindow() {
        NSApp.keyWindow?.performClose(nil)
    }
}

private struct StorageLocationSettingsView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var storageLocationPreferences: StorageLocationPreferences

    @State private var pendingStorageMove: PendingStorageMove?
    @State private var storageMigrationError: String?

    private var storage: ClipboardStorage {
        ClipboardStorage(rootURL: storageLocationPreferences.rootURL)
    }

    private var customCurrentLocation: StorageLocationPreset? {
        guard !StorageLocationPreferences.recommendedLocations().contains(where: {
            StorageLocationPreferences.sameLocation($0.url, storageLocationPreferences.rootURL)
        }) else {
            return nil
        }

        return StorageLocationPreset(
            id: .custom,
            title: "Custom",
            subtitle: "User-selected folder",
            url: storageLocationPreferences.rootURL,
            systemImage: "folder.badge.gearshape"
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Clipboard Markup stores its local app data as a JSON manifest plus a media directory. Move this directory into iCloud Drive, Dropbox, or Google Drive to sync clip metadata, images, marked-up versions, and the agent guide across Macs or make them reachable from mobile cloud-provider apps. You can also choose any custom folder.")
                        .appFont(size: 13)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(StorageLocationPreferences.recommendedLocations()) { preset in
                            StorageLocationPresetRow(
                                preset: preset,
                                isCurrent: isCurrentStorageLocation(preset.url),
                                useAction: {
                                    requestStorageMove(to: preset.url, title: preset.title)
                                },
                                openAction: {
                                    openStorageLocation(preset.url)
                                }
                            )
                        }

                        if let customCurrentLocation {
                            StorageLocationPresetRow(
                                preset: customCurrentLocation,
                                isCurrent: true,
                                useAction: {},
                                openAction: {
                                    openStorageLocation(customCurrentLocation.url)
                                }
                            )
                        }
                    }

                    HStack {
                        Label("Custom folder", systemImage: "folder.badge.gearshape")
                            .appFont(size: 13, weight: .medium)

                        Spacer()

                        Button {
                            chooseCustomFolder()
                        } label: {
                            Label("Choose...", systemImage: "ellipsis.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
                    }
                }
            } header: {
                Text("Storage Location")
                    .appFont(size: 12, weight: .semibold)
            }
        }
        .formStyle(.grouped)
        .alert(
            "Move Clipboard Data?",
            isPresented: Binding(
                get: { pendingStorageMove != nil },
                set: { if !$0 { pendingStorageMove = nil } }
            ),
            presenting: pendingStorageMove
        ) { move in
            Button("Cancel", role: .cancel) {
                pendingStorageMove = nil
            }
            Button("Move Data") {
                moveStorage(to: move)
            }
        } message: { move in
            Text("Clipboard Markup will copy existing entries, media files, and AGENTS.md to \(move.url.path), then use that folder for new clipboard history. Existing Clipboard Markup files in that folder may be replaced. Your current system clipboard and app settings will not be changed.")
        }
        .alert(
            "Could Not Move Clipboard Data",
            isPresented: Binding(
                get: { storageMigrationError != nil },
                set: { if !$0 { storageMigrationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                storageMigrationError = nil
            }
        } message: {
            Text(storageMigrationError ?? "Clipboard Markup could not move its data to the selected folder.")
        }
    }

    private func isCurrentStorageLocation(_ url: URL) -> Bool {
        StorageLocationPreferences.sameLocation(storageLocationPreferences.rootURL, url)
    }

    private func requestStorageMove(to url: URL, title: String, bookmarkData: Data? = nil) {
        let destinationURL = url.standardizedFileURL
        guard !isCurrentStorageLocation(destinationURL) else {
            return
        }
        pendingStorageMove = PendingStorageMove(title: title, url: destinationURL, bookmarkData: bookmarkData)
    }

    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Clipboard Data Folder"
        panel.message = "Choose the folder where Clipboard Markup should store entries.json, AGENTS.md, and clip media."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = storageLocationPreferences.rootURL.deletingLastPathComponent()

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        requestStorageMove(
            to: url,
            title: "Custom Folder",
            bookmarkData: StorageLocationPreferences.securityScopedBookmarkData(for: url)
        )
    }

    private func openStorageLocation(_ url: URL) {
        do {
            let standardizedURL = url.standardizedFileURL
            try FileManager.default.createDirectory(at: standardizedURL, withIntermediateDirectories: true)
            if isCurrentStorageLocation(standardizedURL) {
                try ClipboardStorage(rootURL: standardizedURL).ensureAgentGuide()
            }
            NSWorkspace.shared.open(standardizedURL)
        } catch {
            let move = PendingStorageMove(title: "Storage Location", url: url.standardizedFileURL)
            if let approvedMove = requestStoragePermission(for: move) {
                openStorageLocation(approvedMove.url)
            } else {
                storageMigrationError = error.localizedDescription
            }
        }
    }

    private func moveStorage(to move: PendingStorageMove) {
        pendingStorageMove = nil

        if migrateStorage(to: move) {
            return
        }

        guard let approvedMove = requestStoragePermission(for: move) else {
            storageMigrationError = store.lastError
                ?? "Clipboard Markup could not move its data to \(move.url.path)."
            return
        }

        if !migrateStorage(to: approvedMove) {
            storageMigrationError = store.lastError
                ?? "Clipboard Markup could not move its data to \(approvedMove.url.path)."
        }
    }

    private func migrateStorage(to move: PendingStorageMove) -> Bool {
        _ = move.url.startAccessingSecurityScopedResource()

        guard store.migrateStorage(to: move.url) else {
            return false
        }

        storageLocationPreferences.setRootURL(move.url, bookmarkData: move.bookmarkData)
        try? ClipboardStorage(rootURL: move.url).ensureAgentGuide()
        return true
    }

    private func requestStoragePermission(for move: PendingStorageMove) -> PendingStorageMove? {
        let panel = NSSavePanel()
        panel.title = "Allow Access to \(move.title)"
        panel.message = "Choose or create the ClipboardMarkup folder so macOS can grant Clipboard Markup permission to store its data there."
        panel.prompt = "Allow"
        panel.nameFieldStringValue = move.url.lastPathComponent
        panel.canCreateDirectories = true
        panel.directoryURL = nearestExistingDirectory(containing: move.url)

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let standardizedURL = url.standardizedFileURL
        return PendingStorageMove(
            title: move.title,
            url: standardizedURL,
            bookmarkData: StorageLocationPreferences.securityScopedBookmarkData(for: standardizedURL)
        )
    }

    private func nearestExistingDirectory(containing url: URL) -> URL {
        var candidate = url.deletingLastPathComponent().standardizedFileURL
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        while !fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else {
                return fileManager.homeDirectoryForCurrentUser
            }
            candidate = parent
        }

        return candidate
    }
}

private struct OtherSettingsView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var libraryPreferences: LibraryPreferences
    @ObservedObject var storageLocationPreferences: StorageLocationPreferences

    @State private var didCopyPrompt = false
    @State private var isConfirmingClearHistory = false

    private var storage: ClipboardStorage {
        ClipboardStorage(rootURL: storageLocationPreferences.rootURL)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(storage.agentPromptSnippet)
                        .textSelection(.enabled)
                        .appFont(size: 12, design: .monospaced)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                        }

                    HStack {
                        Spacer()

                        Button {
                            copyPrompt()
                        } label: {
                            Label(didCopyPrompt ? "Copied" : "Copy Prompt", systemImage: didCopyPrompt ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
            } header: {
                Text("Agent Prompt")
                    .appFont(size: 12, weight: .semibold)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Permanently delete all captured clipboard entries and media. This does not change the current system clipboard or app settings.")
                        .appFont(size: 13)
                        .foregroundStyle(.secondary)

                    HStack {
                        Spacer()

                        Button(role: .destructive) {
                            isConfirmingClearHistory = true
                        } label: {
                            Label("Clear Clipboard History...", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            } header: {
                Text("Danger")
                    .appFont(size: 12, weight: .semibold)
            }
        }
        .formStyle(.grouped)
        .alert("Clear Clipboard History?", isPresented: $isConfirmingClearHistory) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("This permanently deletes all saved clipboard entries and media from Clipboard Markup. Your current system clipboard and app settings will not be changed.")
        }
    }

    private func copyPrompt() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(storage.agentPromptSnippet, forType: .string)
        didCopyPrompt = true
    }

    private func openDataDirectory() {
        try? storage.ensureAgentGuide()
        NSWorkspace.shared.open(storage.rootURL)
    }

    private func clearHistory() {
        if store.clearHistory() {
            libraryPreferences.setSelectedItemID(nil)
        }
    }
}

private struct PendingStorageMove: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    var bookmarkData: Data?
}

private struct StorageLocationPresetRow: View {
    let preset: StorageLocationPreset
    let isCurrent: Bool
    let useAction: () -> Void
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: preset.systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(preset.title)
                        .appFont(size: 13, weight: .medium)

                    Text(preset.subtitle)
                        .appFont(size: 12)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    Text(preset.url.path)
                        .appFont(size: 11, design: .monospaced)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .help(preset.url.path)
                        .accessibilityLabel("Full storage path")
                        .accessibilityValue(preset.url.path)
                }
            }

            Spacer()

            Button {
                openAction()
            } label: {
                Label("Open in Finder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if isCurrent {
                Text("Current")
                    .appFont(size: 11, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
            } else {
                Button("Use") {
                    useAction()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(isCurrent ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? Color.blue.opacity(0.30) : Color.secondary.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    @Environment(\.appFontScale) private var appFontScale

    @Binding var shortcut: KeyboardShortcutPreference
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        button.onBeginRecording = {
            isRecording = true
        }
        button.onEndRecording = {
            isRecording = false
        }
        button.onShortcut = { newShortcut in
            shortcut = newShortcut
            isRecording = false
        }
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.title = isRecording ? "Press shortcut" : shortcut.displayLabel
        button.font = .monospacedSystemFont(ofSize: 13 * appFontScale, weight: .medium)
    }
}

private final class ShortcutRecorderButton: NSButton {
    var onBeginRecording: (() -> Void)?
    var onEndRecording: (() -> Void)?
    var onShortcut: ((KeyboardShortcutPreference) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onBeginRecording?()
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            window?.makeFirstResponder(nil)
            onEndRecording?()
            return
        }

        guard let shortcut = KeyboardShortcutPreference.from(event: event) else {
            NSSound.beep()
            return
        }

        onShortcut?(shortcut)
        window?.makeFirstResponder(nil)
    }

    override func resignFirstResponder() -> Bool {
        onEndRecording?()
        return super.resignFirstResponder()
    }
}
