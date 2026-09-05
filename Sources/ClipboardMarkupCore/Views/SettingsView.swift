import AppKit
import Carbon
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var shortcutPreferences: ShortcutPreferences
    @ObservedObject private var appearancePreferences: AppearancePreferences
    @ObservedObject private var store: ClipboardStore
    @ObservedObject private var libraryPreferences: LibraryPreferences
    @ObservedObject private var storageLocationPreferences: StorageLocationPreferences
    @ObservedObject private var launchAtLoginPreferences: LaunchAtLoginPreferences
    @ObservedObject private var analyticsPreferences: AnalyticsPreferences
    private let analyticsRecorder: AnalyticsRecorder
    @State private var isRecordingShortcut = false
    @State private var selectedTab = SettingsTab.appearance
    @State private var isShowingScreenshotSetup = false

    public init(
        shortcutPreferences: ShortcutPreferences,
        appearancePreferences: AppearancePreferences,
        store: ClipboardStore,
        libraryPreferences: LibraryPreferences,
        storageLocationPreferences: StorageLocationPreferences,
        launchAtLoginPreferences: LaunchAtLoginPreferences,
        analyticsPreferences: AnalyticsPreferences,
        analyticsRecorder: AnalyticsRecorder
    ) {
        self.shortcutPreferences = shortcutPreferences
        self.appearancePreferences = appearancePreferences
        self.store = store
        self.libraryPreferences = libraryPreferences
        self.storageLocationPreferences = storageLocationPreferences
        self.launchAtLoginPreferences = launchAtLoginPreferences
        self.analyticsPreferences = analyticsPreferences
        self.analyticsRecorder = analyticsRecorder
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            appearanceForm
                .tabItem { SettingsTabLabel(tab: .appearance) }
                .tag(SettingsTab.appearance)

            shortcutForm
                .tabItem { SettingsTabLabel(tab: .shortcut) }
                .tag(SettingsTab.shortcut)

            StorageLocationSettingsView(
                store: store,
                storageLocationPreferences: storageLocationPreferences,
                analyticsRecorder: analyticsRecorder
            )
                .tabItem { SettingsTabLabel(tab: .storageLocation) }
                .tag(SettingsTab.storageLocation)

            OtherSettingsView(
                store: store,
                libraryPreferences: libraryPreferences,
                storageLocationPreferences: storageLocationPreferences,
                launchAtLoginPreferences: launchAtLoginPreferences,
                analyticsPreferences: analyticsPreferences,
                analyticsRecorder: analyticsRecorder
            )
                .tabItem { SettingsTabLabel(tab: .other) }
                .tag(SettingsTab.other)

            if DeveloperMode.isEnabled {
                DebugSettingsView(analyticsRecorder: analyticsRecorder)
                    .tabItem { SettingsTabLabel(tab: .debug) }
                    .tag(SettingsTab.debug)
            }
        }
        .tint(.blue)
        .padding(18)
        .frame(width: 700, height: 540)
        .onExitCommand(perform: closeSettingsWindow)
        .sheet(isPresented: $isShowingScreenshotSetup) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Screenshot Setup").appFont(size: 24, weight: .semibold)
                ScrollView { ScreenshotSetupView(store: store) }
                HStack {
                    Spacer()
                    Button("Done") { isShowingScreenshotSetup = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 650, height: 500)
        }
        .onAppear {
            analyticsRecorder.record(.settingsOpened)
            analyticsRecorder.record(.settingsSectionOpened(selectedTab.analyticsSection))
        }
        .onChange(of: selectedTab) { _, newValue in
            analyticsRecorder.record(.settingsSectionOpened(newValue.analyticsSection))
        }
    }

    private var appearanceForm: some View {
        Form {
            Section {
                Picker("Theme", selection: Binding(
                    get: { appearancePreferences.colorSchemePreference },
                    set: { appearancePreferences.setColorSchemePreference($0) }
                )) {
                    ForEach(AppColorSchemePreference.allCases) { preference in
                        Text(preference.title)
                            .appFont(size: 13)
                            .tag(preference)
                    }
                }
                .pickerStyle(.segmented)

                Divider()

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
            Section("Screenshots") {
                Text("Screenshots must be copied to the clipboard to appear in your history.")
                Button("Set Up Screenshot Capture…") { isShowingScreenshotSetup = true }
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

private enum SettingsTab: Hashable {
    case appearance
    case shortcut
    case storageLocation
    case other
    case debug

    var analyticsSection: AnalyticsSettingsSection {
        switch self {
        case .appearance:
            .appearance
        case .shortcut:
            .shortcut
        case .storageLocation:
            .storageLocation
        case .other:
            .other
        case .debug:
            .debug
        }
    }

    var title: String {
        switch self {
        case .appearance:
            "Appearance"
        case .shortcut:
            "Shortcut"
        case .storageLocation:
            "Storage Location"
        case .other:
            "Other"
        case .debug:
            "Debug"
        }
    }

    var systemImage: String {
        switch self {
        case .appearance:
            "textformat.size"
        case .shortcut:
            "keyboard"
        case .storageLocation:
            "folder"
        case .other:
            "ellipsis.circle"
        case .debug:
            "ladybug"
        }
    }

    var tabItemWidth: CGFloat {
        switch self {
        case .appearance:
            76
        case .shortcut:
            66
        case .storageLocation:
            104
        case .other:
            54
        case .debug:
            54
        }
    }
}

private struct SettingsTabLabel: View {
    let tab: SettingsTab

    var body: some View {
        Label {
            Text(tab.title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: tab.tabItemWidth)
        } icon: {
            Image(systemName: tab.systemImage)
                .font(.system(size: 18, weight: .regular))
                .frame(width: 24, height: 18)
        }
        .frame(width: tab.tabItemWidth, height: 42)
    }
}

struct StorageLocationSettingsView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var storageLocationPreferences: StorageLocationPreferences
    @ObservedObject var analyticsRecorder: AnalyticsRecorder

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
                                    requestStorageMove(
                                        to: preset.url,
                                        title: preset.title,
                                        provider: AnalyticsStorageProvider(preset: preset.id)
                                    )
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
        requestStorageMove(to: url, title: title, bookmarkData: bookmarkData, provider: .custom)
    }

    private func requestStorageMove(
        to url: URL,
        title: String,
        bookmarkData: Data? = nil,
        provider: AnalyticsStorageProvider
    ) {
        let destinationURL = url.standardizedFileURL
        guard !isCurrentStorageLocation(destinationURL) else {
            return
        }
        pendingStorageMove = PendingStorageMove(
            title: title,
            url: destinationURL,
            provider: provider,
            bookmarkData: bookmarkData
        )
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
            bookmarkData: StorageLocationPreferences.securityScopedBookmarkData(for: url),
            provider: .custom
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
            let move = PendingStorageMove(title: "Storage Location", url: url.standardizedFileURL, provider: .custom)
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
        analyticsRecorder.record(.storageLocationChanged(move.provider))
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
            provider: move.provider,
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
    @ObservedObject var launchAtLoginPreferences: LaunchAtLoginPreferences
    @ObservedObject var analyticsPreferences: AnalyticsPreferences
    @ObservedObject var analyticsRecorder: AnalyticsRecorder

    @State private var didCopyPrompt = false
    @State private var isConfirmingClearHistory = false

    private var storage: ClipboardStorage {
        ClipboardStorage(rootURL: storageLocationPreferences.rootURL)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(
                        "Launch Clipboard Markup at login",
                        isOn: Binding(
                            get: { launchAtLoginPreferences.status.isOn },
                            set: { launchAtLoginPreferences.setLaunchAtLoginEnabled($0) }
                        )
                    )
                    .appFont(size: 13)
                    .disabled(launchAtLoginPreferences.status == .unavailable)

                    Label(launchAtLoginPreferences.status.displayText, systemImage: launchAtLoginStatusSystemImage)
                        .appFont(size: 12)
                        .foregroundStyle(.secondary)

                    if launchAtLoginPreferences.status.canOpenSystemSettings {
                        Button {
                            launchAtLoginPreferences.openSystemSettingsLoginItems()
                        } label: {
                            Label("Open Login Items Settings", systemImage: "gearshape")
                        }
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("Startup")
                    .appFont(size: 12, weight: .semibold)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(
                        "Share privacy-safe usage analytics",
                        isOn: Binding(
                            get: { analyticsPreferences.isSharingEnabled },
                            set: { analyticsRecorder.setSharingEnabled($0) }
                        )
                    )
                    .appFont(size: 13)

                    Label(analyticsRecorder.status.displayText, systemImage: analyticsStatusSystemImage)
                        .appFont(size: 12)
                        .foregroundStyle(.secondary)

                    Text("Analytics helps understand whether people are using Clipboard Markup and which features are useful. It never includes clipboard contents, OCR text, clip titles, search queries, file paths, media filenames, or password-manager contents.")
                        .appFont(size: 12)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("Usage Analytics")
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
        .onAppear {
            launchAtLoginPreferences.refresh()
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

    private var analyticsStatusSystemImage: String {
        switch analyticsRecorder.status {
        case .enabled:
            "checkmark.circle.fill"
        case .disabled:
            "pause.circle"
        case .missingConfiguration, .configurationError:
            "exclamationmark.triangle.fill"
        case .paused:
            "clock"
        case .stoppedByServer:
            "stop.circle"
        }
    }

    private var launchAtLoginStatusSystemImage: String {
        switch launchAtLoginPreferences.status {
        case .off:
            "power.circle"
        case .enabled:
            "checkmark.circle.fill"
        case .requiresApproval:
            "exclamationmark.triangle.fill"
        case .unavailable:
            "xmark.circle"
        case .error:
            "exclamationmark.circle.fill"
        }
    }
}

private struct DebugSettingsView: View {
    @ObservedObject var analyticsRecorder: AnalyticsRecorder

    @State private var snapshot: AnalyticsDebugSnapshot
    @State private var lastRefreshedAt = Date()

    init(analyticsRecorder: AnalyticsRecorder) {
        self.analyticsRecorder = analyticsRecorder
        _snapshot = State(initialValue: analyticsRecorder.makeDebugSnapshot())
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Label(snapshot.status.displayText, systemImage: statusSystemImage)
                            .appFont(size: 13, weight: .medium)

                        Spacer()

                        Button {
                            analyticsRecorder.flushSoon()
                            refresh()
                        } label: {
                            Label("Flush Now", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)

                        Button {
                            refresh()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Refresh analytics debug status")
                        .accessibilityLabel("Refresh analytics debug status")
                    }

                    DebugFieldGrid {
                        DebugField(label: "Sharing", value: snapshot.isSharingEnabled ? "On" : "Off")
                        DebugField(label: "Server control", value: snapshot.isStoppedByServer ? "Stopped" : "Active")
                        DebugField(label: "Install ID", value: snapshot.installID)
                        DebugField(label: "Session ID", value: snapshot.sessionID)
                        DebugField(label: "Refreshed", value: DateFormatting.absolute.string(from: lastRefreshedAt))
                    }
                }
            } header: {
                Text("Analytics Status")
                    .appFont(size: 12, weight: .semibold)
            }

            Section {
                DebugFieldGrid {
                    DebugField(label: "Config", value: snapshot.configuration.statusText)
                    DebugField(label: "Audience", value: snapshot.configuration.audience?.rawValue ?? "none")
                    DebugField(label: "Namespace", value: snapshot.configuration.namespace ?? "none")
                    DebugField(label: "Key ID", value: snapshot.configuration.keyID ?? "none")
                    DebugField(label: "App", value: appSummary)
                    DebugField(label: "Base URL", value: snapshot.configuration.baseURLString ?? "none", isMonospaced: true)
                    if let redirectedBaseURLString = snapshot.configuration.redirectedBaseURLString {
                        DebugField(label: "Redirect", value: redirectedBaseURLString, isMonospaced: true)
                    }
                }
            } header: {
                Text("Configuration")
                    .appFont(size: 12, weight: .semibold)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        DebugCountPill(
                            title: "Synced",
                            value: "\(snapshot.queue.successfullySyncedEventCount)",
                            systemImage: "checkmark.circle.fill",
                            tint: .green
                        )
                        DebugCountPill(
                            title: "Total",
                            value: "\(snapshot.queue.totalEventCount)",
                            systemImage: "sum",
                            tint: .blue
                        )
                        DebugCountPill(
                            title: "Pending",
                            value: "\(snapshot.queue.queuedEventCount)",
                            systemImage: "clock",
                            tint: .secondary
                        )
                    }

                    DebugFieldGrid {
                        DebugField(label: "Queued events", value: "\(snapshot.queue.queuedEventCount)")
                        DebugField(label: "Prepared batch", value: snapshot.queue.preparedBatchID.map(shortID) ?? "none")
                        DebugField(label: "Prepared events", value: "\(snapshot.queue.preparedBatchEventCount)")
                        DebugField(label: "Compressed bytes", value: snapshot.queue.preparedBatchCompressedBytes.map(String.init) ?? "none")
                        DebugField(label: "Retry attempt", value: "\(snapshot.queue.retryAttempt)")
                        DebugField(label: "Next retry", value: snapshot.queue.nextRetryAt.map(DateFormatting.absolute.string(from:)) ?? "none")
                        DebugField(label: "Queue file", value: snapshot.queue.statePath, isMonospaced: true)
                    }
                }
            } header: {
                Text("Queue")
                    .appFont(size: 12, weight: .semibold)
            }

            Section {
                if snapshot.queue.recentQueuedEvents.isEmpty {
                    Text("No queued analytics events.")
                        .appFont(size: 12)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(snapshot.queue.recentQueuedEvents) { event in
                            AnalyticsDebugEventRow(event: event)
                        }
                    }
                }
            } header: {
                Text("Queued Events")
                    .appFont(size: 12, weight: .semibold)
            }

            Section {
                if snapshot.queue.recentSyncedBatches.isEmpty {
                    Text("No synced analytics batches yet.")
                        .appFont(size: 12)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(snapshot.queue.recentSyncedBatches) { batch in
                            AnalyticsSyncedBatchRow(batch: batch)
                        }
                    }
                }
            } header: {
                Text("Synced Batches")
                    .appFont(size: 12, weight: .semibold)
            }
        }
        .formStyle(.grouped)
    }

    private var statusSystemImage: String {
        switch snapshot.status {
        case .enabled:
            "checkmark.circle.fill"
        case .disabled:
            "pause.circle"
        case .missingConfiguration, .configurationError:
            "exclamationmark.triangle.fill"
        case .paused:
            "clock"
        case .stoppedByServer:
            "stop.circle"
        }
    }

    private var appSummary: String {
        [
            snapshot.configuration.appName,
            snapshot.configuration.appVersion,
            snapshot.configuration.platform
        ]
        .compactMap { $0 }
        .joined(separator: " / ")
    }

    private func refresh() {
        snapshot = analyticsRecorder.makeDebugSnapshot()
        lastRefreshedAt = Date()
    }

    private func shortID(_ id: String) -> String {
        guard id.count > 10 else {
            return id
        }
        return "\(id.prefix(8))..."
    }
}

private struct DebugFieldGrid<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 7) {
            content
        }
    }
}

private struct DebugField: View {
    let label: String
    let value: String
    var isMonospaced = false

    var body: some View {
        GridRow {
            Text(label)
                .appFont(size: 12, weight: .medium)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)

            Text(value)
                .appFont(size: 12, design: isMonospaced ? .monospaced : .default)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(value)
        }
    }
}

private struct DebugCountPill: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .appFont(size: 14, weight: .semibold, design: .monospaced)
                    .foregroundStyle(tint)
                Text(title)
                    .appFont(size: 10.5, weight: .medium)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(tint.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct AnalyticsDebugEventRow: View {
    let event: AnalyticsDebugEvent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.type)
                    .appFont(size: 12.5, weight: .semibold, design: .monospaced)
                Text(metadata)
                    .appFont(size: 11)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let value = event.value {
                Text(value)
                    .appFont(size: 11, weight: .medium, design: .monospaced)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
        }
    }

    private var metadata: String {
        "\(event.audience.rawValue)  Enqueued \(DateFormatting.relativeDisplay(for: event.enqueuedAt))"
    }
}

private struct AnalyticsSyncedBatchRow: View {
    let batch: AnalyticsDebugSyncedBatch

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(shortID(batch.batchId))
                        .appFont(size: 12.5, weight: .semibold, design: .monospaced)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Spacer()

                Text(DateFormatting.relativeDisplay(for: batch.uploadedAt))
                    .appFont(size: 11)
                    .foregroundStyle(.green)
            }

            Text("\(batch.eventCount) events / \(batch.compressedByteCount) compressed bytes / \(batch.audience.rawValue)")
                .appFont(size: 11)
                .foregroundStyle(.secondary)

            Text(batch.eventTypes.isEmpty ? "No event type details" : batch.eventTypes.joined(separator: ", "))
                .appFont(size: 11, design: .monospaced)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(8)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.green.opacity(0.22), lineWidth: 1)
        }
    }

    private func shortID(_ id: String) -> String {
        guard id.count > 10 else {
            return id
        }
        return "\(id.prefix(8))..."
    }
}

private struct PendingStorageMove: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let provider: AnalyticsStorageProvider
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
