import AppKit
import SwiftUI

struct ClipboardDetailView: View {
    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem
    @State private var isEditingMarkup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeader(store: store, item: item)
                DetailActionBar(store: store, item: item, isEditingMarkup: $isEditingMarkup)

                Divider()

                switch item.kind {
                case .text:
                    TextDetailView(store: store, item: item)
                case .image:
                    ImageDetailView(store: store, item: item)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isEditingMarkup) {
            if let original = store.image(for: item, variant: .original) {
                MarkupEditorView(
                    originalImage: original,
                    initialElements: item.markups,
                    onCancel: {
                        isEditingMarkup = false
                    },
                    onSave: { elements in
                        store.updateMarkups(itemID: item.id, elements: elements)
                        isEditingMarkup = false
                    }
                )
                .frame(minWidth: 980, minHeight: 680)
            } else {
                ContentUnavailableView("Image Missing", systemImage: "exclamationmark.triangle")
                    .frame(minWidth: 420, minHeight: 280)
            }
        }
    }
}

private struct DetailHeader: View {
    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: item.kind == .image ? "photo" : "doc.text")
                .appFont(size: 24, weight: .medium)
                .foregroundStyle(.secondary)
                .frame(width: 42, height: 42)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                EditableTitleField(store: store, item: item)

                HStack(spacing: 10) {
                    Text("\(item.subtitle)  \(DateFormatting.absolute.string(from: item.createdAt))")
                        .appFont(size: 13)
                        .foregroundStyle(.secondary)

                    if item.kind == .image {
                        Button("View Original") {
                            store.quickLook(itemID: item.id, variant: .original)
                        }
                        .buttonStyle(.link)
                        .appFont(size: 13)
                        .help("Quick Look the original image")
                    }
                }
            }

            Spacer()

            HeaderFavoriteButton(store: store, item: item)
        }
    }
}

private struct EditableTitleField: View {
    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem

    @FocusState private var isFocused: Bool
    @State private var draftTitle = ""

    var body: some View {
        TextField("Name", text: $draftTitle)
            .focused($isFocused)
            .textFieldStyle(.plain)
            .appFont(size: 17, weight: .semibold)
            .lineLimit(2)
            .help("Rename clip")
            .onSubmit(commitRename)
            .onAppear {
                draftTitle = item.title
            }
            .onChange(of: item.id) { _, _ in
                draftTitle = item.title
            }
            .onChange(of: item.title) { _, newTitle in
                if !isFocused {
                    draftTitle = newTitle
                }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    commitRename()
                }
            }
    }

    private func commitRename() {
        store.rename(itemID: item.id, title: draftTitle)
        draftTitle = store.item(id: item.id)?.title ?? item.title
    }
}

private struct HeaderFavoriteButton: View {
    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        Button {
            store.toggleSaved(itemID: item.id)
        } label: {
            Image(systemName: item.isSaved ? "star.fill" : "star")
                .appFont(size: 18, weight: .semibold)
                .foregroundStyle(item.isSaved ? Color.yellow : Color.secondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("d", modifiers: [.command])
        .help(item.isSaved ? "Remove from Favorites (Command-D)" : "Add to Favorites (Command-D)")
    }
}

private struct DetailActionBar: View {
    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem
    @Binding var isEditingMarkup: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                switch item.kind {
                case .text:
                    textActions
                case .image:
                    imageActions
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var textActions: some View {
        Group {
            ActionButton(
                title: "Copy",
                systemImage: item.hasRichText ? "textformat" : "text.alignleft",
                shortcut: "⌘C"
            ) {
                store.copyPreferred(itemID: item.id)
            }
            .keyboardShortcut("c", modifiers: [.command])

            if item.hasRichText {
                ActionButton(title: "Plain Text", systemImage: "text.alignleft", shortcut: "⌥⌘C") {
                    store.copyText(itemID: item.id, variant: .plain)
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
            }
        }
    }

    private var imageActions: some View {
        Group {
            ActionButton(
                title: "Copy",
                systemImage: "doc.on.doc",
                shortcut: "⌘C"
            ) {
                store.copyImage(itemID: item.id, variant: .preferred)
            }
            .keyboardShortcut("c", modifiers: [.command])

            ActionButton(title: "Markup", systemImage: "square.and.pencil", shortcut: "⌘E") {
                isEditingMarkup = true
            }
            .keyboardShortcut("e", modifiers: [.command])

            ActionButton(title: "Preview", systemImage: "macwindow", shortcut: "⇧⌘O") {
                store.openInPreview(itemID: item.id, variant: .preferred)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            ActionButton(title: "Quick Look", systemImage: "eye", shortcut: "Space") {
                store.quickLook(itemID: item.id, variant: .preferred)
            }
            .keyboardShortcut(.space, modifiers: [])
        }
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Label(title, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
                ShortcutBadge(shortcut)
            }
            .appFont(size: 13)
            .padding(.horizontal, 2)
            .frame(minHeight: 26)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

private struct ShortcutBadge: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .appFont(size: 10, weight: .medium, design: .monospaced)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct TextDetailView: View {
    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.plainText ?? "")
                .textSelection(.enabled)
                .appFont(size: 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct ImageDetailView: View {
    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let image = store.image(for: item, variant: .preferred) {
                ZStack {
                    Color.secondary.opacity(0.055)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                }
                .frame(maxWidth: .infinity, minHeight: 500, maxHeight: 620)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
                }
            } else {
                ContentUnavailableView("Image Missing", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
