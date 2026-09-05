import AppKit
import SwiftUI

struct ScreenshotSetupView: View {
    @ObservedObject var store: ClipboardStore
    @State private var destination = ScreenshotDestination.read()
    @State private var initialImageIDs: Set<UUID> = []
    @State private var receivedImage = false
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(destination.message, systemImage: destination == .clipboard ? "checkmark.circle" : "info.circle")
                .appFont(size: 15, weight: .semibold)

            Text("Clipboard Markup receives images copied to the clipboard. Screenshots saved only to the Desktop or another folder won’t appear here.")

            Text("Press Shift–Command–5 to open Screenshot. Select a still-image capture tool, then open Options and choose Clipboard under Save to, if available.")

            HStack {
                Button("Open Screenshot Options…", action: openScreenshot)
                Button("Check Setting Again") { destination = .read() }
            }

            Text("If Clipboard isn’t listed, use Control–Shift–Command–4 to copy a selected area. To change the shortcut permanently, open System Settings → Keyboard → Keyboard Shortcuts → Screenshots and assign your preferred keys to “Copy picture of selected area to the clipboard”. Remove any conflicting shortcut from “Save picture of selected area as a file”.")

            Divider()

            Label(
                receivedImage ? "Image received and saved — clipboard capture is working." : "Try taking a screenshot now. We’ll confirm here when an image is saved.",
                systemImage: receivedImage ? "checkmark.circle.fill" : "camera"
            )
            .foregroundStyle(receivedImage ? Color.green : Color.secondary)

            if let error = launchError ?? store.lastError {
                Text(error).foregroundStyle(.red)
            }
        }
        .appFont(size: 13)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            initialImageIDs = Set(store.items.filter { $0.kind == .image }.map(\.id))
            destination = .read()
        }
        .onChange(of: store.items) { _, items in
            if items.contains(where: { $0.kind == .image && !initialImageIDs.contains($0.id) }), store.lastError == nil {
                receivedImage = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            destination = .read()
        }
    }

    private func openScreenshot() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app")
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            Task { @MainActor in
                launchError = error.map { "Could not open Screenshot: \($0.localizedDescription). Press Shift–Command–5 instead." }
            }
        }
    }
}
