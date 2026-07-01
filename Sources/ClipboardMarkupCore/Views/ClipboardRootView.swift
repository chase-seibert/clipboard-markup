import AppKit
import SwiftUI

public struct ClipboardRootView: View {
    @Environment(\.undoManager) private var undoManager

    @ObservedObject private var store: ClipboardStore
    @ObservedObject private var commandRelay: AppCommandRelay
    @ObservedObject private var libraryPreferences: LibraryPreferences
    private let analyticsRecorder: AnalyticsRecorder

    @State private var searchText = ""
    @State private var searchFocusRequestID = 0

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
        NavigationSplitView {
            SidebarView(
                store: store,
                libraryFilter: libraryFilterBinding,
                selectedID: selectedIDBinding,
                searchText: $searchText,
                searchFocusRequestID: searchFocusRequestID,
                items: displayedItems,
                onRenameSelection: commandRelay.renameSelectedClip,
                onQuickLookSelection: quickLookSelectedItem,
                onDeleteSelection: deleteSelectedItem,
                onDeleteItem: deleteItem,
                onRestoreItem: restoreItem,
                analyticsRecorder: analyticsRecorder
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 360, max: 700)
        } detail: {
            if let item = store.item(id: libraryPreferences.selectedItemID) {
                ClipboardDetailView(
                    store: store,
                    commandRelay: commandRelay,
                    analyticsRecorder: analyticsRecorder,
                    item: item
                ) {
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
        .focusedSceneValue(\.clipboardCommandContext, commandContext)
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
        .onChange(of: libraryPreferences.filter) { _, newFilter in
            analyticsRecorder.record(.libraryFilterChanged(AnalyticsLibraryFilter(filter: newFilter)))
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

    private var selectedItem: ClipboardItem? {
        store.item(id: libraryPreferences.selectedItemID)
    }

    private var commandContext: ClipboardCommandContext {
        ClipboardCommandContext(
            item: selectedItem,
            copy: copySelectedItem,
            copyAlternate: copyAlternateSelectedItem,
            markup: commandRelay.markupSelectedClip,
            quickLook: { _ = quickLookSelectedItem() },
            rename: commandRelay.renameSelectedClip,
            toggleFavorite: toggleFavoriteSelectedItem,
            delete: deleteSelectedItem,
            restore: restoreSelectedItem
        )
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

    private func restoreSelectedItem() {
        guard let selectedID = libraryPreferences.selectedItemID else {
            return
        }

        restoreItem(selectedID)
    }

    private func deleteItem(_ itemID: ClipboardItem.ID) {
        store.delete(itemID: itemID, undoManager: undoManager)
        selectFallbackItem()
    }

    private func restoreItem(_ itemID: ClipboardItem.ID) {
        store.restore(itemID: itemID, undoManager: undoManager)
        selectFallbackItem()
    }

    private func handleSearchRequestIfNeeded() {
        guard commandRelay.consumeSearchRequestIfNeeded() else {
            return
        }

        searchFocusRequestID += 1
    }

    private func copySelectedItem() {
        guard let selectedID = libraryPreferences.selectedItemID else {
            return
        }

        store.copyPreferred(itemID: selectedID)
    }

    private func copyAlternateSelectedItem() {
        guard let selectedItem else {
            return
        }

        switch selectedItem.kind {
        case .text:
            store.copyText(itemID: selectedItem.id, variant: .plain)
        case .image:
            store.copyImage(itemID: selectedItem.id, variant: .original)
        }
    }

    @discardableResult
    private func quickLookSelectedItem() -> Bool {
        guard let selectedItem, selectedItem.kind == .image else {
            return false
        }

        store.quickLook(itemID: selectedItem.id, variant: .preferred)
        return true
    }

    private func toggleFavoriteSelectedItem() {
        guard let selectedID = libraryPreferences.selectedItemID else {
            return
        }

        store.toggleSaved(itemID: selectedID, undoManager: undoManager)
    }
}

private struct SidebarView: View {
    @Environment(\.undoManager) private var undoManager

    @ObservedObject var store: ClipboardStore
    @Binding var libraryFilter: LibraryFilter
    @Binding var selectedID: ClipboardItem.ID?
    @Binding var searchText: String
    let searchFocusRequestID: Int
    let items: [ClipboardItem]
    let onRenameSelection: () -> Void
    let onQuickLookSelection: () -> Bool
    let onDeleteSelection: () -> Void
    let onDeleteItem: (ClipboardItem.ID) -> Void
    let onRestoreItem: (ClipboardItem.ID) -> Void
    let analyticsRecorder: AnalyticsRecorder

    @FocusState private var isListFocused: Bool
    @State private var isSearchFieldPresented = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ExpandingSearchField(
                    text: $searchText,
                    isPresented: $isSearchFieldPresented,
                    focusRequestID: searchFocusRequestID,
                    onOpen: {
                        analyticsRecorder.record(.searchOpened)
                    },
                    onSubmit: submitSearch
                )

                FilterMenu(selection: $libraryFilter, isCompact: isSearchFieldPresented)
            }
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 7)

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
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    selectedID = item.id
                                    isListFocused = true
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                            .onDrag {
                                store.itemProvider(itemID: item.id) ?? NSItemProvider()
                            }
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
                                        store.toggleSaved(itemID: item.id, undoManager: undoManager)
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
                .focusable()
                .focused($isListFocused)
                .onDeleteCommand(perform: onDeleteSelection)
                .onKeyPress { keyPress in
                    guard keyPress.key == .return,
                          keyPress.modifiers.contains(.command)
                    else {
                        return .ignored
                    }

                    onRenameSelection()
                    return .handled
                }
                .onKeyPress(.space) {
                    onQuickLookSelection() ? .handled : .ignored
                }
                .onKeyPress(.delete) {
                    onDeleteSelection()
                    return .handled
                }
                .onKeyPress(.deleteForward) {
                    onDeleteSelection()
                    return .handled
                }
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

    private func submitSearch(_ query: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalizedQuery.isEmpty {
            libraryFilter = .allClips
            analyticsRecorder.record(.searchSubmitted)
        }

        searchText = normalizedQuery
    }
}

private struct FilterMenu: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selection: LibraryFilter
    let isCompact: Bool

    var body: some View {
        Menu {
            ForEach(LibraryFilter.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    Label {
                        HStack(spacing: 16) {
                            Text(filter.title)

                            Spacer(minLength: 24)

                            FilterShortcutBadge(filter.keyboardShortcutLabel)
                        }
                    } icon: {
                        Image(systemName: menuIcon(for: filter))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .appFont(size: 12, weight: .medium)

                if !isCompact {
                    Text(activeFilter.title)
                        .appFont(size: 12, weight: .medium)
                        .lineLimit(1)

                    FilterShortcutBadge(activeFilter.keyboardShortcutLabel)
                }

                Image(systemName: "chevron.down")
                    .appFont(size: 8, weight: .semibold)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, isCompact ? 0 : 9)
            .frame(width: isCompact ? 36 : nil, height: 28)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.82), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            }
            .fixedSize(horizontal: !isCompact, vertical: false)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: isCompact)
        }
        .menuStyle(.borderlessButton)
        .help("Filter clips: \(activeFilter.title)")
        .accessibilityLabel("Filter clips")
        .accessibilityValue(activeFilter.title)
    }

    private var activeFilter: LibraryFilter {
        selection
    }

    private func menuIcon(for filter: LibraryFilter) -> String {
        filter == activeFilter ? "checkmark" : filter.systemImage
    }
}

private struct FilterShortcutBadge: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .appFont(size: 10, weight: .medium, design: .monospaced)
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct ExpandingSearchField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var text: String
    @Binding var isPresented: Bool
    let focusRequestID: Int
    let onOpen: () -> Void
    let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool
    @State private var isExpanded = false
    @State private var draftText = ""

    private var showsField: Bool {
        isExpanded || isFocused || !draftText.isEmpty || !text.isEmpty
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                expandAndFocus()
            } label: {
                Image(systemName: "magnifyingglass")
                    .appFont(size: 14, weight: .semibold)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(showsField ? Color.primary : Color.secondary)
            .help("Search clips (Command-F)")
            .accessibilityLabel("Search clips")

            if showsField {
                TextField("Search", text: $draftText)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .appFont(size: 13)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .onSubmit {
                        onSubmit(draftText)
                    }

                if !draftText.isEmpty || !text.isEmpty {
                    Button {
                        clearAndCollapse()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .appFont(size: 12)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
            }
        }
        .padding(.horizontal, showsField ? 9 : 5)
        .frame(width: showsField ? nil : 32, height: 28, alignment: .leading)
        .frame(maxWidth: showsField ? .infinity : 32, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.82), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .clipped()
        .animation(searchAnimation, value: showsField)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .onExitCommand(perform: clearAndCollapse)
        .onAppear {
            draftText = text
            isPresented = showsField
        }
        .onChange(of: text) { _, newValue in
            guard newValue != draftText else {
                return
            }

            draftText = newValue
        }
        .onChange(of: showsField) { _, newValue in
            isPresented = newValue
        }
        .onChange(of: focusRequestID) { _, _ in
            expandAndFocus()
        }
        .onChange(of: isFocused) { _, focused in
            guard !focused,
                  text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return
            }

            withAnimation(searchAnimation) {
                isExpanded = false
            }
        }
    }

    private func expandAndFocus() {
        onOpen()
        withAnimation(searchAnimation) {
            isExpanded = true
            isPresented = true
        }

        DispatchQueue.main.async {
            isFocused = true
        }
    }

    private func clearAndCollapse() {
        draftText = ""
        text = ""
        isFocused = false

        withAnimation(searchAnimation) {
            isExpanded = false
            isPresented = false
        }
    }

    private var searchAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.16)
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
                .layoutPriority(1)
        }
    }

    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            metadataView

            rowPreview
                .frame(maxWidth: .infinity)
                .frame(height: fixedStackedPreviewHeight, alignment: .top)
                .frame(maxHeight: stackedThumbnailHeight, alignment: .top)
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

    private var fixedStackedPreviewHeight: CGFloat? {
        item.kind == .image ? stackedThumbnailHeight : nil
    }

    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .appFont(size: 13.2, weight: .semibold)
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
                TextSnippetPreviewTile(text: item.plainText ?? "", maximumHeight: stackedThumbnailHeight)
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
    let maximumHeight: CGFloat

    private let fontSize: CGFloat = 12
    private let horizontalPadding: CGFloat = 9
    private let verticalPadding: CGFloat = 8

    var body: some View {
        Text(previewText)
            .appFont(size: fontSize)
            .foregroundStyle(Color.primary.opacity(0.78))
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: maximumHeight, alignment: .top)
            .clipped()
    }

    private var previewText: String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "No text" : trimmedText
    }

    private var lineLimit: Int {
        let scaledFontSize = max(8, fontSize * CGFloat(appFontScale))
        let lineHeight = scaledFontSize * 1.22
        let contentHeight = max(0, maximumHeight - (verticalPadding * 2))
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
                        .allowsHitTesting(false)
                        .accessibilityLabel("Magnified thumbnail detail")
                        .accessibilityHint("Shows the center of the screenshot at original size.")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
            }
            .onAppear {
                #if DEBUG
                StartupTimingLogger.markOnce(
                    .firstVisibleImageThumbnail,
                    "first visible image thumbnail",
                    metadata: "imagePoints=\(Int(round(image.size.width)))x\(Int(round(image.size.height))) thumbnailPoints=\(Int(round(size.width)))x\(Int(round(size.height)))"
                )
                #endif
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
