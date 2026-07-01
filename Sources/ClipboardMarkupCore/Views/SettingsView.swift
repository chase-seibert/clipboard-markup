import AppKit
import Carbon
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var shortcutPreferences: ShortcutPreferences
    @ObservedObject private var appearancePreferences: AppearancePreferences
    @ObservedObject private var store: ClipboardStore
    @ObservedObject private var libraryPreferences: LibraryPreferences
    private let storage = ClipboardStorage()
    @State private var isRecordingShortcut = false

    public init(
        shortcutPreferences: ShortcutPreferences,
        appearancePreferences: AppearancePreferences,
        store: ClipboardStore,
        libraryPreferences: LibraryPreferences
    ) {
        self.shortcutPreferences = shortcutPreferences
        self.appearancePreferences = appearancePreferences
        self.store = store
        self.libraryPreferences = libraryPreferences
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

            DataSettingsView(
                storage: storage,
                store: store,
                libraryPreferences: libraryPreferences
            )
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
        }
        .padding(20)
        .frame(width: 620, height: 540)
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
                    Text(shortcutPreferences.isRegistered ? "Registered" : "Not registered")
                        .appFont(size: 12)
                        .foregroundStyle(shortcutPreferences.isRegistered ? Color.secondary : Color.red)

                    Spacer()

                    Button("Reset") {
                        shortcutPreferences.resetToDefault()
                    }
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
}

private struct DataSettingsView: View {
    let storage: ClipboardStorage
    @ObservedObject var store: ClipboardStore
    @ObservedObject var libraryPreferences: LibraryPreferences

    @State private var didCopyPrompt = false
    @State private var isConfirmingClearHistory = false

    var body: some View {
        Form {
            Section {
                Text("Clipboard Markup stores its local app data as a JSON manifest plus a media directory. This makes it easy for coding agents to inspect clipboard history when you explicitly point them at the files.")
                    .appFont(size: 13)
                    .foregroundStyle(.secondary)

                DataDirectoryRow(
                    path: storage.rootURL.path,
                    openAction: openDataDirectory
                )
            } header: {
                Text("Local Data")
                    .appFont(size: 12, weight: .semibold)
            }

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
        .onAppear {
            try? storage.ensureAgentGuide()
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

private struct DataDirectoryRow: View {
    let path: String
    let openAction: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Data directory")
                    .appFont(size: 12, weight: .medium)
                    .foregroundStyle(.secondary)

                Text(path)
                    .textSelection(.enabled)
                    .appFont(size: 11, design: .monospaced)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                openAction()
            } label: {
                Label("Open in Finder", systemImage: "folder")
            }
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
