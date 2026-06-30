import AppKit
import SwiftUI

public struct ClipboardMenuBarExtraContent: View {
    @ObservedObject private var store: ClipboardStore
    @ObservedObject private var commandRelay: AppCommandRelay

    public init(store: ClipboardStore, commandRelay: AppCommandRelay) {
        self.store = store
        self.commandRelay = commandRelay
    }

    public var body: some View {
        Button {
            commandRelay.showMainWindow()
        } label: {
            Label("Open Clipboard Markup", systemImage: "macwindow")
        }

        Divider()

        if store.items.isEmpty {
            Text("No clips yet")
        } else {
            ForEach(Array(store.items.prefix(5))) { item in
                Button {
                    store.copyPreferred(itemID: item.id)
                } label: {
                    Label(
                        MenuBarTitleFormatter.title(for: item),
                        systemImage: item.kind == .image ? "photo" : "doc.text"
                    )
                }
            }
        }

        Divider()

        SettingsLink {
            Label("Settings...", systemImage: "gearshape")
        }

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit", systemImage: "power")
        }
    }
}
