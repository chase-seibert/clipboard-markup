import AppKit
import SwiftUI

struct ClipboardDetailView: View {
    @Environment(\.undoManager) private var undoManager

    @ObservedObject var store: ClipboardStore
    @ObservedObject var commandRelay: AppCommandRelay
    let item: ClipboardItem
    let onDelete: () -> Void
    let onRestore: () -> Void
    @State private var isEditingMarkup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailHeader(
                    store: store,
                    item: item,
                    renameRequestID: commandRelay.renameRequestID,
                    onDelete: onDelete,
                    onRestore: onRestore
                )

                if item.isDeleted {
                    DeletedItemNotice(item: item, onRestore: onRestore)
                } else {
                    DetailActionBar(store: store, item: item, isEditingMarkup: $isEditingMarkup)
                }

                Divider()

                switch item.kind {
                case .text:
                    TextDetailView(store: store, item: item)
                case .image:
                    ImageDetailView(store: store, item: item)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)
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
                        store.updateMarkups(itemID: item.id, elements: elements, undoManager: undoManager)
                        isEditingMarkup = false
                    }
                )
                .frame(minWidth: 980, minHeight: 680)
            } else {
                ContentUnavailableView("Image Missing", systemImage: "exclamationmark.triangle")
                    .frame(minWidth: 420, minHeight: 280)
            }
        }
        .onChange(of: commandRelay.markupRequestID) { _, _ in
            guard item.kind == .image, !item.isDeleted else {
                return
            }
            isEditingMarkup = true
        }
    }
}

private struct DetailHeader: View {
    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem
    let renameRequestID: Int
    let onDelete: () -> Void
    let onRestore: () -> Void
    @State private var titleFocusRequest = 0

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: headerIconSystemName)
                .symbolRenderingMode(.hierarchical)
                .appFont(size: 21, weight: .semibold)
                .foregroundStyle(Color.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.22), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    RenameTitleButton {
                        titleFocusRequest += 1
                    }

                    EditableTitleField(store: store, item: item, focusRequest: titleFocusRequest)
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Text(metadataText)
                        .appFont(size: 13)
                        .foregroundStyle(.secondary)

                    if item.kind == .image && !item.isDeleted {
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

            HStack(spacing: 8) {
                if item.isDeleted {
                    HeaderRestoreButton(onRestore: onRestore)
                } else {
                    HeaderFavoriteButton(store: store, item: item)
                    HeaderDeleteButton(onDelete: onDelete)
                }
            }
        }
        .onChange(of: renameRequestID) { _, _ in
            titleFocusRequest += 1
        }
    }

    private var headerIconSystemName: String {
        item.kind == .image ? "photo.on.rectangle" : "doc.text"
    }

    private var metadataText: String {
        if let deletedAt = item.deletedAt {
            return "\(item.subtitle)  Deleted \(DateFormatting.absolute.string(from: deletedAt))"
        }

        return "\(item.subtitle)  \(DateFormatting.absolute.string(from: item.createdAt))"
    }
}

private struct RenameTitleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("✏️")
                .appFont(size: 13)
                .frame(width: 23, height: 23)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .help("Rename clip")
        .accessibilityLabel("Rename clip")
    }
}

private struct EditableTitleField: View {
    @Environment(\.undoManager) private var undoManager

    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem
    let focusRequest: Int

    @FocusState private var isFocused: Bool
    @State private var draftTitle = ""

    var body: some View {
        TextField("Name", text: $draftTitle)
            .focused($isFocused)
            .textFieldStyle(.plain)
            .appFont(size: 18, weight: .semibold)
            .lineLimit(2)
            .help("Rename clip")
            .onSubmit(commitRename)
            .onAppear {
                draftTitle = item.title
            }
            .onChange(of: focusRequest) { _, _ in
                isFocused = true
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
        store.rename(itemID: item.id, title: draftTitle, undoManager: undoManager)
        draftTitle = store.item(id: item.id)?.title ?? item.title
    }
}

private struct HeaderFavoriteButton: View {
    @Environment(\.undoManager) private var undoManager

    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        Button {
            store.toggleSaved(itemID: item.id, undoManager: undoManager)
        } label: {
            Image(systemName: item.isSaved ? "star.fill" : "star")
                .symbolRenderingMode(.hierarchical)
                .appFont(size: 17, weight: .semibold)
                .foregroundStyle(item.isSaved ? Color.yellow : Color.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(item.isSaved ? Color.yellow.opacity(0.16) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(item.isSaved ? Color.yellow.opacity(0.34) : Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .help(item.isSaved ? "Remove from Favorites (Command-D)" : "Add to Favorites (Command-D)")
        .accessibilityLabel(item.isSaved ? "Remove from Favorites" : "Add to Favorites")
    }
}

private struct HeaderDeleteButton: View {
    let onDelete: () -> Void

    var body: some View {
        Button(role: .destructive, action: onDelete) {
            Image(systemName: "trash")
                .symbolRenderingMode(.hierarchical)
                .appFont(size: 17, weight: .semibold)
                .foregroundStyle(.red)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
        }
        .help("Delete clip")
        .accessibilityLabel("Delete clip")
    }
}

private struct HeaderRestoreButton: View {
    let onRestore: () -> Void

    var body: some View {
        Button(action: onRestore) {
            Image(systemName: "arrow.uturn.backward")
                .symbolRenderingMode(.hierarchical)
                .appFont(size: 17, weight: .semibold)
                .foregroundStyle(Color.blue)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.blue.opacity(0.22), lineWidth: 1)
        }
        .help("Restore clip")
        .accessibilityLabel("Restore clip")
    }
}

private struct DeletedItemNotice: View {
    let item: ClipboardItem
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(message, systemImage: "trash")
                .appFont(size: 13)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Button {
                onRestore()
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.regular)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var message: String {
        guard let deletedAt = item.deletedAt else {
            return "This item is in Deleted Items."
        }

        let purgeDate = deletedAt.addingTimeInterval(ClipboardItem.deletedItemRetentionInterval)
        return "This item is in Deleted Items and will be permanently deleted \(DateFormatting.relativeDisplay(for: purgeDate))."
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
                shortcut: "⌘C",
                prominence: .primary
            ) {
                store.copyPreferred(itemID: item.id)
            }

            if item.hasRichText {
                ActionButton(title: "Plain Text", systemImage: "text.alignleft", shortcut: "⌥⌘C") {
                    store.copyText(itemID: item.id, variant: .plain)
                }
            }
        }
    }

    private var imageActions: some View {
        Group {
            ActionButton(
                title: "Copy",
                systemImage: "doc.on.doc",
                shortcut: "⌘C",
                prominence: .primary
            ) {
                store.copyImage(itemID: item.id, variant: .preferred)
            }

            ActionButton(title: "Markup", systemImage: "square.and.pencil", shortcut: "⌘E") {
                isEditingMarkup = true
            }

            ActionButton(title: "Preview", systemImage: "macwindow", shortcut: "⇧⌘O") {
                store.openInPreview(itemID: item.id, variant: .preferred)
            }

            ActionButton(title: "Quick Look", systemImage: "eye", shortcut: "Space") {
                store.quickLook(itemID: item.id, variant: .preferred)
            }
        }
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let shortcut: String
    var prominence: DetailActionProminence = .secondary
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if prominence == .primary {
            Button(action: action) {
                label(isPrimary: true)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.regular)
        } else {
            Button(action: action) {
                label(isPrimary: false)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private func label(isPrimary: Bool) -> some View {
        HStack(spacing: 7) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .symbolRenderingMode(.hierarchical)

            ShortcutBadge(shortcut, style: isPrimary ? .onAccent : .normal)
        }
        .appFont(size: 13, weight: isPrimary ? .semibold : .regular)
        .foregroundStyle(isPrimary ? Color.white : Color.primary)
        .padding(.horizontal, 2)
        .frame(minHeight: 27)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        "\(title), shortcut \(shortcut)"
    }
}

private enum DetailActionProminence {
    case primary
    case secondary
}

private struct ShortcutBadge: View {
    enum Style {
        case normal
        case onAccent
    }

    let value: String
    let style: Style

    init(_ value: String, style: Style = .normal) {
        self.value = value
        self.style = style
    }

    var body: some View {
        Text(value)
            .appFont(size: 10, weight: .medium, design: .monospaced)
            .foregroundStyle(style == .onAccent ? Color.white.opacity(0.82) : Color.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(badgeBackground, in: RoundedRectangle(cornerRadius: 4))
    }

    private var badgeBackground: Color {
        style == .onAccent ? Color.white.opacity(0.18) : Color.secondary.opacity(0.10)
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
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
                }
                .onDrag {
                    store.itemProvider(itemID: item.id) ?? NSItemProvider()
                }
        }
    }
}

private struct ImageDetailView: View {
    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let image = store.image(for: item, variant: .preferred) {
                ScreenshotPreviewSurface(image: image)
                    .frame(maxWidth: .infinity, minHeight: 500, maxHeight: 620)
                    .onDrag {
                        store.itemProvider(itemID: item.id) ?? NSItemProvider()
                    }
            } else {
                ContentUnavailableView("Image Missing", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

private struct ScreenshotPreviewSurface: View {
    let image: NSImage

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size
            let inset: CGFloat = 22
            let availableSize = CGSize(
                width: max(canvasSize.width - inset * 2, 1),
                height: max(canvasSize.height - inset * 2, 1)
            )
            let fittedRect = fittedImageRect(imageSize: image.size, containerSize: availableSize)
                .offsetBy(dx: inset, dy: inset)

            ZStack {
                Color.secondary.opacity(0.08)

                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: fittedRect.width, height: fittedRect.height)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay {
                        Rectangle()
                            .stroke(Color.primary.opacity(0.34), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.24), radius: 11, x: 0, y: 4)
                    .position(x: fittedRect.midX, y: fittedRect.midY)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.22), lineWidth: 1)
        }
    }
}

private func fittedImageRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
        return .zero
    }

    let imageAspect = imageSize.width / imageSize.height
    let containerAspect = containerSize.width / containerSize.height
    let size: CGSize

    if imageAspect > containerAspect {
        size = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
    } else {
        size = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
    }

    return CGRect(
        x: (containerSize.width - size.width) / 2,
        y: (containerSize.height - size.height) / 2,
        width: size.width,
        height: size.height
    )
}
