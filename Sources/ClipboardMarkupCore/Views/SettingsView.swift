import AppKit
import Carbon
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var shortcutPreferences: ShortcutPreferences
    @ObservedObject private var appearancePreferences: AppearancePreferences
    @State private var isRecordingShortcut = false

    public init(shortcutPreferences: ShortcutPreferences, appearancePreferences: AppearancePreferences) {
        self.shortcutPreferences = shortcutPreferences
        self.appearancePreferences = appearancePreferences
    }

    public var body: some View {
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
        .padding(20)
        .frame(width: 500, height: 420)
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
