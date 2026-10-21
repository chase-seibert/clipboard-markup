import AppKit
import SwiftUI

public struct ClipboardMenuBarExtraContent: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    @ObservedObject private var store: ClipboardStore
    @ObservedObject private var commandRelay: AppCommandRelay
    @ObservedObject private var libraryPreferences: LibraryPreferences
    private let analyticsRecorder: AnalyticsRecorder

    public init(
        store: ClipboardStore,
        commandRelay: AppCommandRelay,
        libraryPreferences: LibraryPreferences,
        analyticsRecorder: AnalyticsRecorder
    ) {
        self.store = store
        self.commandRelay = commandRelay
        self.libraryPreferences = libraryPreferences
        self.analyticsRecorder = analyticsRecorder
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if recentItems.isEmpty && favoriteItems.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    clipSection(title: "Recent", items: recentItems)
                    clipSection(title: "Favorites", items: favoriteItems)
                }
                .padding(8)
            }

            Divider()

            footer
        }
        .frame(width: 380)
        .onAppear {
            analyticsRecorder.record(.appMenuBarOpened)
        }
    }

    private var recentItems: [ClipboardItem] {
        Array(store.items.filter { !$0.isDeleted }.prefix(5))
    }

    private var favoriteItems: [ClipboardItem] {
        Array(store.items.filter { !$0.isDeleted && $0.isSaved }.prefix(3))
    }

    @ViewBuilder
    private func clipSection(title: String, items: [ClipboardItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .appFont(size: 10.5, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .padding(.horizontal, 4)

                ForEach(items) { item in
                    RecentClipPanelRow(
                        item: item,
                        image: item.kind == .image ? store.image(for: item, variant: .preferred) : nil
                    ) {
                        store.copyPreferred(itemID: item.id)
                        dismiss()
                    } onMarkup: {
                        openMarkup(for: item)
                    } onQuickLook: {
                        quickLook(item)
                    } onToggleFavorite: {
                        store.toggleSaved(itemID: item.id)
                    }
                }
            }
        }
    }

    private func openMarkup(for item: ClipboardItem) {
        guard item.kind == .image, !item.isDeleted else {
            return
        }

        selectInMainWindow(item)
        analyticsRecorder.record(.clipAction(.markupOpened))
        commandRelay.markupSelectedClip()
        dismiss()
    }

    private func quickLook(_ item: ClipboardItem) {
        guard item.kind == .image, !item.isDeleted else {
            return
        }

        store.quickLook(itemID: item.id, variant: .preferred)
        dismiss()
    }

    private func selectInMainWindow(_ item: ClipboardItem) {
        if !libraryPreferences.filter.matches(item) {
            libraryPreferences.setFilter(item.kind == .image ? .images : .text)
        }

        libraryPreferences.setSelectedItemID(item.id)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("Clipboard Markup", systemImage: "doc.on.clipboard")
                .symbolRenderingMode(.hierarchical)
                .appFont(size: 13, weight: .semibold)

            Spacer()

            Button {
                commandRelay.showMainWindow()
                dismiss()
            } label: {
                Label("Open", systemImage: "macwindow")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .symbolRenderingMode(.hierarchical)
                .appFont(size: 28, weight: .semibold)
                .foregroundStyle(.secondary)

            Text("No clips yet")
                .appFont(size: 13, weight: .semibold)

            Text("Copied text and images will appear here.")
                .appFont(size: 12)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                openSettings()
                dismiss()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct RecentClipPanelRow: View {
    let item: ClipboardItem
    let image: NSImage?
    let onCopy: () -> Void
    let onMarkup: () -> Void
    let onQuickLook: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onCopy) {
                HStack(spacing: 10) {
                    RecentClipPreview(item: item, image: image)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(MenuBarTitleFormatter.title(for: item, limit: 44))
                            .appFont(size: 12.5)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(metadataText)
                            .appFont(size: 11)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Image(systemName: "doc.on.doc")
                        .symbolRenderingMode(.hierarchical)
                        .appFont(size: 13, weight: .semibold)
                        .foregroundStyle(isHovering ? Color.blue : Color.secondary)
                        .frame(width: 18, height: 22)
                }
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)

            if item.kind == .image {
                RowIconButton(
                    systemName: "square.and.pencil",
                    foregroundStyle: Color.blue,
                    accessibilityLabel: "Markup \(item.title)",
                    action: onMarkup
                )

                RowIconButton(
                    systemName: "eye",
                    foregroundStyle: Color.secondary,
                    accessibilityLabel: "Quick Look \(item.title)",
                    action: onQuickLook
                )
            }

            RowIconButton(
                systemName: item.isSaved ? "star.fill" : "star",
                foregroundStyle: item.isSaved ? Color.yellow : Color.secondary,
                accessibilityLabel: item.isSaved ? "Remove \(item.title) from Favorites" : "Add \(item.title) to Favorites",
                action: onToggleFavorite
            )
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowBorder, lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .accessibilityLabel("Copy \(item.title)")
    }

    private var metadataText: String {
        "\(item.subtitle) - \(DateFormatting.relativeDisplay(for: item.createdAt))"
    }

    private var rowBackground: Color {
        isHovering ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.06)
    }

    private var rowBorder: Color {
        isHovering ? Color.accentColor.opacity(0.24) : Color.secondary.opacity(0.12)
    }
}

private struct RowIconButton: View {
    let systemName: String
    let foregroundStyle: Color
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .appFont(size: 13, weight: .semibold)
                .foregroundStyle(foregroundStyle)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct RecentClipPreview: View {
    let item: ClipboardItem
    let image: NSImage?

    private let size = NSSize(width: 86, height: 58)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            preview

            if item.isSaved {
                Image(systemName: "star.fill")
                    .symbolRenderingMode(.hierarchical)
                    .appFont(size: 9, weight: .semibold)
                    .foregroundStyle(.yellow)
                    .shadow(radius: 1)
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var preview: some View {
        if let thumbnail = MenuBarThumbnailRenderer.thumbnail(for: image, size: size) {
            Image(nsImage: thumbnail)
                .resizable()
                .interpolation(.high)
                .frame(width: size.width, height: size.height)
        } else if item.kind == .text {
            Text(textPreview)
                .appFont(size: 9.5)
                .foregroundStyle(Color.primary.opacity(0.72))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .padding(6)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
        } else {
            Image(systemName: "photo")
                .symbolRenderingMode(.hierarchical)
                .appFont(size: 20, weight: .semibold)
                .foregroundStyle(.secondary)
                .frame(width: size.width, height: size.height)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
        }
    }

    private var textPreview: String {
        let trimmedText = item.textPreview(maxCharacters: 240).text
        return trimmedText.isEmpty ? "Text" : trimmedText
    }
}
