import SwiftUI

public struct OnboardingView: View {
    @ObservedObject private var store: ClipboardStore
    @ObservedObject private var preferences: StorageLocationPreferences
    private let analyticsRecorder: AnalyticsRecorder
    @State private var isChoosingLocation = false
    @State private var validationError: String?
    @State private var isScreenshotStep = false

    public init(
        store: ClipboardStore,
        preferences: StorageLocationPreferences,
        analyticsRecorder: AnalyticsRecorder
    ) {
        self.store = store
        self.preferences = preferences
        self.analyticsRecorder = analyticsRecorder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(isScreenshotStep ? "Capture screenshots to the clipboard" : "Welcome to Clipboard Markup", systemImage: isScreenshotStep ? "camera" : "doc.on.clipboard")
                .appFont(size: 24, weight: .semibold)

            Text(isScreenshotStep ? "Step 2 of 2 · Screenshots" : "Step 1 of 2 · Storage")
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isScreenshotStep {
                        ScreenshotSetupView(store: store)
                    } else {
                        storageChoices
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let validationError {
                Label("Could not write to this folder: \(validationError)", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if isScreenshotStep {
                    Button("Back") { isScreenshotStep = false }
                } else {
                    Button(isChoosingLocation ? "Hide Folder Choices" : "Choose a Different Folder…") {
                        isChoosingLocation.toggle()
                    }
                }
                Spacer()
                Button(isScreenshotStep ? "Finish Setup" : (preferences.isUsingDefaultLocation ? "Use Default Folder" : "Use This Folder")) {
                    do {
                        if isScreenshotStep {
                            try preferences.completeOnboarding()
                        } else {
                            try ClipboardStorage(rootURL: preferences.rootURL).validateWritable()
                            validationError = nil
                            isScreenshotStep = true
                        }
                    } catch {
                        validationError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 740, height: isChoosingLocation && !isScreenshotStep ? 660 : 510)
        .interactiveDismissDisabled()
        .onChange(of: preferences.rootURL) { _, _ in
            validationError = nil
        }
    }

    private var storageChoices: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Choose where to save your clipboard history and images. The default folder on this Mac is ready to use. You can change this later in Settings → Storage Location.")
                .appFont(size: 14)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Label(preferences.isUsingDefaultLocation ? "Default folder on this Mac" : "Your storage folder", systemImage: "folder")
                    .appFont(size: 14, weight: .semibold)
                Text(preferences.rootURL.path)
                    .appFont(size: 12, design: .monospaced)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isChoosingLocation {
                StorageLocationSettingsView(
                    store: store,
                    storageLocationPreferences: preferences,
                    analyticsRecorder: analyticsRecorder
                )
                .frame(height: 360)
            }
        }
    }
}
