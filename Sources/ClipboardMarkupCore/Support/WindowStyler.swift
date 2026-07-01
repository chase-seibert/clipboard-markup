import AppKit
import SwiftUI

struct WindowStyler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            style(window: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            style(window: view.window)
        }
    }

    private func style(window: NSWindow?) {
        guard let window else {
            return
        }

        window.tabbingMode = .disallowed
        window.titleVisibility = .visible
        window.toolbarStyle = .automatic
        window.setFrameAutosaveName("ClipboardMarkupMainWindow")
    }
}
