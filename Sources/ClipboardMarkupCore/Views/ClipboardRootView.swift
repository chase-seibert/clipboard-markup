import AppKit
import SwiftUI

public struct ClipboardRootView: View {
    @ObservedObject private var store: ClipboardStore
    @ObservedObject private var commandRelay: AppCommandRelay
    @ObservedObject private var libraryPreferences: LibraryPreferences

    @State private var searchText = ""
    @State private var searchFocusRequestID = 0

    public init(
        store: ClipboardStore,
        commandRelay: AppCommandRelay,
        libraryPreferences: LibraryPreferences
    ) {
        self.store = store
        self.commandRelay = commandRelay
        self.libraryPreferences = libraryPreferences
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                store: store,
                libraryFilter: libraryFilterBinding,
                selectedID: selectedIDBinding,
                searchText: $searchText,
                searchFocusRequestID: searchFocusRequestID,
                items: displayedItems,
                onDeleteSelection: deleteSelectedItem,
                onDeleteItem: deleteItem,
                onRestoreItem: restoreItem
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 620)
        } detail: {
            if let item = store.item(id: libraryPreferences.selectedItemID) {
                ClipboardDetailView(store: store, item: item) {
                    deleteItem(item.id)
                } onRestore: {
                    restoreItem(item.id)
                }
                    .id(item.id)
            } else {
                ContentUnavailableView("No Selection", systemImage: "doc.on.clipboard")
            }
        }
        .background(WindowStyler().frame(width: 0, height: 0))
        .modifier(WindowCommandInstaller(commandRelay: commandRelay))
        .onAppear {
            selectFallbackItem()
            handleSearchRequestIfNeeded()
        }
        .onChange(of: store.items.map(\.id)) { oldIDs, newIDs in
            if let newestID = newIDs.first, !oldIDs.contains(newestID) {
                navigateToNewItem(newestID)
            } else {
                selectFallbackItem()
            }
        }
        .onChange(of: libraryPreferences.filter) { _, _ in
            selectFallbackItem()
        }
        .onChange(of: commandRelay.searchRequestID) { _, _ in
            handleSearchRequestIfNeeded()
        }
    }

    private var displayedItems: [ClipboardItem] {
        let activeFilter = libraryPreferences.filter

        let matchingItems = store.items.filter { item in
            activeFilter.matches(item) && item.matchesSearch(searchText)
        }

        if activeFilter == .deleted {
            return matchingItems.sorted {
                ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast)
            }
        }

        return matchingItems
    }

    private var libraryFilterBinding: Binding<LibraryFilter> {
        Binding {
            libraryPreferences.filter
        } set: { filter in
            libraryPreferences.setFilter(filter)
        }
    }

    private var selectedIDBinding: Binding<ClipboardItem.ID?> {
        Binding {
            libraryPreferences.selectedItemID
        } set: { selectedID in
            libraryPreferences.setSelectedItemID(selectedID)
        }
    }

    private func selectFallbackItem() {
        let ids = Set(displayedItems.map(\.id))
        if let selectedID = libraryPreferences.selectedItemID, ids.contains(selectedID) {
            return
        }
        libraryPreferences.setSelectedItemID(displayedItems.first?.id)
    }

    private func navigateToNewItem(_ itemID: ClipboardItem.ID) {
        guard let item = store.item(id: itemID) else {
            return
        }

        if !libraryPreferences.filter.matches(item) {
            libraryPreferences.setFilter(item.kind == .image ? .images : .text)
        }

        if !item.matchesSearch(searchText) {
            searchText = ""
        }

        libraryPreferences.setSelectedItemID(itemID)
    }

    private func deleteSelectedItem() {
        guard let selectedID = libraryPreferences.selectedItemID else {
            return
        }

        deleteItem(selectedID)
    }

    private func deleteItem(_ itemID: ClipboardItem.ID) {
        store.delete(itemID: itemID)
        selectFallbackItem()
    }

    private func restoreItem(_ itemID: ClipboardItem.ID) {
        store.restore(itemID: itemID)
        selectFallbackItem()
    }

    private func handleSearchRequestIfNeeded() {
        guard commandRelay.consumeSearchRequestIfNeeded() else {
            return
        }

        searchFocusRequestID += 1
    }
}

private struct SidebarView: View {
    @ObservedObject var store: ClipboardStore
    @Binding var libraryFilter: LibraryFilter
    @Binding var selectedID: ClipboardItem.ID?
    @Binding var searchText: String
    let searchFocusRequestID: Int
    let items: [ClipboardItem]
    let onDeleteSelection: () -> Void
    let onDeleteItem: (ClipboardItem.ID) -> Void
    let onRestoreItem: (ClipboardItem.ID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                ExpandingSearchField(text: $searchText, focusRequestID: searchFocusRequestID)

                FilterMenu(selection: $libraryFilter)
                    .frame(width: 38)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if items.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptySystemImage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedID) {
                    ForEach(items) { item in
                        ClipboardRow(store: store, item: item)
                            .tag(item.id)
                            .contextMenu {
                                if item.isDeleted {
                                    Button {
                                        onRestoreItem(item.id)
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                } else {
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

                                    Divider()

                                    Button(role: .destructive) {
                                        onDeleteItem(item.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
                .onDeleteCommand(perform: onDeleteSelection)
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
        libraryFilter
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

private struct FilterMenu: View {
    @Binding var selection: LibraryFilter

    var body: some View {
        Menu {
            ForEach(LibraryFilter.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    Label(filter.title, systemImage: menuIcon(for: filter))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .appFont(size: 12, weight: .medium)

                Image(systemName: "chevron.down")
                    .appFont(size: 9, weight: .semibold)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .help("Filter clips: \(activeFilter.title)")
    }

    private var activeFilter: LibraryFilter {
        selection
    }

    private func menuIcon(for filter: LibraryFilter) -> String {
        filter == activeFilter ? "checkmark" : filter.systemImage
    }
}

private struct ExpandingSearchField: View {
    @Binding var text: String
    let focusRequestID: Int

    @FocusState private var isFocused: Bool
    @State private var isExpanded = false

    private var showsField: Bool {
        isExpanded || isFocused || !text.isEmpty
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                expandAndFocus()
            } label: {
                Image(systemName: "magnifyingglass")
                    .appFont(size: 15, weight: .semibold)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Search clips (Command-F)")

            if showsField {
                TextField("Search", text: $text)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .appFont(size: 13)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                if !text.isEmpty {
                    Button {
                        text = ""
                        isFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .appFont(size: 12)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
        }
        .padding(.horizontal, showsField ? 9 : 5)
        .frame(width: showsField ? 170 : 32, height: 28, alignment: .leading)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .clipped()
        .animation(.easeInOut(duration: 0.16), value: showsField)
        .onChange(of: focusRequestID) { _, _ in
            expandAndFocus()
        }
        .onChange(of: isFocused) { _, focused in
            guard !focused, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            withAnimation(.easeInOut(duration: 0.16)) {
                isExpanded = false
            }
        }
    }

    private func expandAndFocus() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isExpanded = true
        }

        DispatchQueue.main.async {
            isFocused = true
        }
    }
}

private struct ClipboardRow: View {
    @Environment(\.appThumbnailSize) private var thumbnailSize

    @ObservedObject var store: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        Group {
            if usesStackedLayout {
                stackedRow
            } else {
                compactRow
            }
        }
        .padding(.vertical, usesStackedLayout ? 7 : 5)
    }

    private var compactRow: some View {
        HStack(spacing: 10) {
            rowPreview
                .frame(width: thumbnailWidth, height: thumbnailHeight)

            metadataView
        }
    }

    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            metadataView

            rowPreview
                .frame(maxWidth: .infinity)
                .frame(height: stackedThumbnailHeight)
        }
    }

    private var thumbnailWidth: CGFloat {
        thumbnailSize
    }

    private var thumbnailHeight: CGFloat {
        round(thumbnailSize * 0.72)
    }

    private var stackedThumbnailHeight: CGFloat {
        round(thumbnailSize * 0.86)
    }

    private var usesStackedLayout: Bool {
        item.kind == .text || (item.kind == .image && thumbnailSize >= 120)
    }

    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .appFont(size: 13, weight: .semibold)
                .lineLimit(1)

            HStack(spacing: 6) {
                if let deletedAt = item.deletedAt {
                    Text("Deleted")
                    Text(DateFormatting.relativeDisplay(for: deletedAt))
                } else {
                    Text(item.subtitle)
                    Text(DateFormatting.relativeDisplay(for: item.createdAt))
                }
            }
            .appFont(size: 10.5)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var rowPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            if item.kind == .text {
                TextSnippetPreviewTile(text: item.plainText ?? "")
            } else if item.kind == .image,
               let image = store.image(for: item, variant: .preferred) {
                ImageHybridThumbnail(image: image)
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
            } else {
                Image(systemName: item.kind == .image ? "photo" : "doc.text")
                    .foregroundStyle(.secondary)
                    .appFont(size: 17)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    }
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

private struct TextSnippetPreviewTile: View {
    @Environment(\.appFontScale) private var appFontScale

    let text: String

    private let fontSize: CGFloat = 12
    private let verticalPadding: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            Text(previewText)
                .appFont(size: fontSize)
                .foregroundStyle(Color.primary.opacity(0.78))
                .lineLimit(lineLimit(for: geometry.size.height))
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 9)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                }
                .clipped()
        }
    }

    private var previewText: String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "No text" : trimmedText
    }

    private func lineLimit(for height: CGFloat) -> Int {
        let scaledFontSize = max(8, fontSize * CGFloat(appFontScale))
        let lineHeight = scaledFontSize * 1.22
        let contentHeight = max(0, height - (verticalPadding * 2))
        return max(1, Int(floor(contentHeight / lineHeight)))
    }
}

private struct ImageHybridThumbnail: View {
    let image: NSImage

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let lensDiameter = magnifierDiameter(for: size)

            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()

                if shouldShowMagnifier(for: size) {
                    OneToOneMagnifierLens(image: image, diameter: lensDiameter)
                        .position(x: size.width / 2, y: size.height / 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private func magnifierDiameter(for thumbnailSize: CGSize) -> CGFloat {
        let available = max(1, min(thumbnailSize.width, thumbnailSize.height) - 14)
        return min(max(45, round(available * 0.93)), 198)
    }

    private func shouldShowMagnifier(for thumbnailSize: CGSize) -> Bool {
        displayedScale(for: thumbnailSize) < 0.5
    }

    private func displayedScale(for thumbnailSize: CGSize) -> CGFloat {
        guard image.size.width > 0, image.size.height > 0 else {
            return 1
        }

        return max(
            thumbnailSize.width / image.size.width,
            thumbnailSize.height / image.size.height
        )
    }
}

private struct OneToOneMagnifierLens: View {
    let image: NSImage
    let diameter: CGFloat

    var body: some View {
        ZStack(alignment: .center) {
            Color(nsColor: .textBackgroundColor)
                .opacity(0.96)

            Image(nsImage: image)
                .resizable()
                .frame(
                    width: image.size.width,
                    height: image.size.height,
                    alignment: .topLeading
                )
                .clipped()
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(0.46), lineWidth: 1.5)
        }
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                .padding(2)
        }
        .background {
            Circle()
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.30), radius: 6, x: 0, y: 3)
        }
        .overlay(alignment: .bottomTrailing) {
            Capsule()
                .fill(Color.primary.opacity(0.50))
                .frame(width: max(16, diameter * 0.34), height: max(4, diameter * 0.085))
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                }
                .rotationEffect(.degrees(45))
                .offset(x: diameter * 0.13, y: diameter * 0.13)
                .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: 1)
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
