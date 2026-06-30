import AppKit
import SwiftUI

public struct ClipboardRootView: View {
    @ObservedObject private var store: ClipboardStore
    @ObservedObject private var commandRelay: AppCommandRelay

    @State private var libraryFilter: LibraryFilter? = .images
    @State private var selectedID: ClipboardItem.ID?
    @State private var searchText = ""

    public init(store: ClipboardStore, commandRelay: AppCommandRelay) {
        self.store = store
        self.commandRelay = commandRelay
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                store: store,
                libraryFilter: $libraryFilter,
                selectedID: $selectedID,
                searchText: $searchText,
                items: displayedItems
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 620)
        } detail: {
            if let item = store.item(id: selectedID) {
                ClipboardDetailView(store: store, item: item)
                    .id(item.id)
            } else {
                ContentUnavailableView("No Selection", systemImage: "doc.on.clipboard")
            }
        }
        .background(WindowStyler().frame(width: 0, height: 0))
        .modifier(WindowCommandInstaller(commandRelay: commandRelay))
        .onAppear {
            selectFallbackItem()
        }
        .onChange(of: displayedItems.map(\.id)) { _, _ in
            selectFallbackItem()
        }
        .onChange(of: libraryFilter) { _, _ in
            selectFallbackItem()
        }
    }

    private var displayedItems: [ClipboardItem] {
        let activeFilter = libraryFilter ?? .images

        return store.items.filter { item in
            activeFilter.matches(item) && item.matchesSearch(searchText)
        }
    }

    private func selectFallbackItem() {
        let ids = Set(displayedItems.map(\.id))
        if let selectedID, ids.contains(selectedID) {
            return
        }
        selectedID = displayedItems.first?.id
    }
}

private struct SidebarView: View {
    @ObservedObject var store: ClipboardStore
    @Binding var libraryFilter: LibraryFilter?
    @Binding var selectedID: ClipboardItem.ID?
    @Binding var searchText: String
    let items: [ClipboardItem]

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            List(selection: $libraryFilter) {
                Section("Library") {
                    ForEach(LibraryFilter.allCases) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                            .appFont(size: 13, weight: filter == activeFilter ? .semibold : .regular)
                            .tag(filter)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(height: 176)

            if items.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptySystemImage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedID) {
                    Section(activeFilter.listSectionTitle) {
                    ForEach(items) { item in
                        ClipboardRow(store: store, item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button {
                                    store.copyPreferred(itemID: item.id)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }

                                Button {
                                    store.toggleSaved(itemID: item.id)
                                } label: {
                                    Label(item.isSaved ? "Unfavorite" : "Favorite", systemImage: item.isSaved ? "star.slash" : "star")
                                }
                            }
                    }
                    }
                }
                .listStyle(.sidebar)
            }

            if let lastError = store.lastError {
                Text(lastError)
                    .appFont(size: 11)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(8)
            }
        }
    }

    private var activeFilter: LibraryFilter {
        libraryFilter ?? .images
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyTitle: String {
        if isSearching {
            return "No Results"
        }
        return activeFilter.emptyTitle
    }

    private var emptySystemImage: String {
        if isSearching {
            return "magnifyingglass"
        }
        return activeFilter.systemImage
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .appFont(size: 12)

            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .appFont(size: 13)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .appFont(size: 12)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct ClipboardRow: View {
    @Environment(\.appThumbnailSize) private var thumbnailSize

    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 10) {
            rowPreview
                .frame(width: thumbnailWidth, height: thumbnailHeight)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .appFont(size: 13, weight: .semibold)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.subtitle)
                    Text(DateFormatting.relativeDisplay(for: item.createdAt))
                }
                .appFont(size: 10.5)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
    }

    private var thumbnailWidth: CGFloat {
        thumbnailSize
    }

    private var thumbnailHeight: CGFloat {
        round(thumbnailSize * 0.72)
    }

    @ViewBuilder
    private var rowPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            if item.kind == .image,
               let image = store.image(for: item, variant: .preferred) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    }
            } else {
                Image(systemName: item.kind == .image ? "photo" : "doc.text")
                    .foregroundStyle(.secondary)
                    .appFont(size: 17)
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            }

            if item.isSaved {
                Image(systemName: "star.fill")
                    .appFont(size: 9, weight: .semibold)
                    .foregroundStyle(.yellow)
                    .shadow(radius: 1)
                    .offset(x: 2, y: 2)
            }
        }
    }
}

private struct WindowCommandInstaller: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    let commandRelay: AppCommandRelay

    func body(content: Content) -> some View {
        content
            .onAppear {
                commandRelay.showWindowHandler = {
                    showMainWindow()
                }
            }
    }

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        if let existingWindow = NSApp.windows.first(where: { $0.title.contains("Clipboard Markup") }) {
            existingWindow.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.title.contains("Clipboard Markup") })?.makeKeyAndOrderFront(nil)
        }
    }
}
