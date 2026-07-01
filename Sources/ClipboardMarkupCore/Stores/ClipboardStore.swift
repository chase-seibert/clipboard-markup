import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
public final class ClipboardStore: ObservableObject {
    public enum TextCopyVariant: Hashable {
        case plain
        case rich
    }

    public enum ImageVariant: Hashable {
        case preferred
        case original
        case marked
    }

    @Published public private(set) var items: [ClipboardItem] = []
    @Published public private(set) var lastError: String?
    public weak var analyticsRecorder: AnalyticsRecording?

    private var storage: ClipboardStorage
    private let monitor: PasteboardMonitor
    private var transcriptionTasks: [ClipboardItem.ID: Task<Void, Never>] = [:]
    private var purgeTimer: Timer?

    public convenience init() {
        let storageLocationPreferences = StorageLocationPreferences()
        #if DEBUG
        StartupTimingLogger.mark(
            "storage root resolved",
            metadata: "location=\(Self.startupStorageLocationKind(for: storageLocationPreferences.rootURL)) custom=\(!storageLocationPreferences.isUsingDefaultLocation)"
        )
        #endif
        self.init(
            storage: ClipboardStorage(rootURL: storageLocationPreferences.rootURL),
            monitor: PasteboardMonitor()
        )
    }

    init(storage: ClipboardStorage, monitor: PasteboardMonitor) {
        self.storage = storage
        self.monitor = monitor

        #if DEBUG
        let storeInitToken = StartupTimingLogger.begin("clipboard store init")
        #endif
        reloadItemsFromStorage()

        monitor.onCapture = { [weak self] capture in
            self?.record(capture)
        }

        transcribePendingImages()
        #if DEBUG
        StartupTimingLogger.end(storeInitToken, metadata: "items=\(items.count)")
        #endif
    }

    public var dataDirectoryURL: URL {
        storage.rootURL
    }

    private func reloadItemsFromStorage() {
        do {
            #if DEBUG
            let loadedItems = try StartupTimingLogger.measure(
                "history manifest load",
                metadata: { "items=\($0.count)" }
            ) {
                try storage.loadItems().sorted { $0.createdAt > $1.createdAt }
            }
            let retainedItems = try StartupTimingLogger.measure(
                "expired item purge",
                metadata: { "kept=\($0.count) removed=\(loadedItems.count - $0.count)" }
            ) {
                try storage.purgeExpiredDeletedItems(from: loadedItems)
            }
            #else
            let loadedItems = try storage.loadItems().sorted { $0.createdAt > $1.createdAt }
            let retainedItems = try storage.purgeExpiredDeletedItems(from: loadedItems)
            #endif
            self.items = retainedItems

            if retainedItems.count != loadedItems.count {
                #if DEBUG
                try StartupTimingLogger.measure("pruned manifest save") {
                    try storage.saveItems(retainedItems)
                }
                #else
                try storage.saveItems(retainedItems)
                #endif
            }
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
            self.items = []
        }
    }

    public var savedItems: [ClipboardItem] {
        items.filter { $0.isSaved && !$0.isDeleted }
    }

    public func startMonitoring() {
        #if DEBUG
        StartupTimingLogger.mark("store monitoring start")
        #endif
        monitor.start()
        purgeExpiredDeletedItems()
        startPurgeTimer()
    }

    @discardableResult
    public func clearHistory() -> Bool {
        do {
            for task in transcriptionTasks.values {
                task.cancel()
            }
            transcriptionTasks.removeAll()

            try storage.clearHistory()
            items = []
            lastError = nil
            monitor.acceptCurrentChangeCount()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    public func migrateStorage(to rootURL: URL) -> Bool {
        let destinationRootURL = rootURL.standardizedFileURL
        guard !StorageLocationPreferences.sameLocation(storage.rootURL, destinationRootURL) else {
            return true
        }

        do {
            try storage.saveItems(items)
            try storage.copyData(to: destinationRootURL)

            for task in transcriptionTasks.values {
                task.cancel()
            }
            transcriptionTasks.removeAll()

            storage = ClipboardStorage(rootURL: destinationRootURL)
            reloadItemsFromStorage()
            transcribePendingImages()
            return lastError == nil
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    public func item(id: ClipboardItem.ID?) -> ClipboardItem? {
        guard let id else {
            return nil
        }
        return items.first { $0.id == id }
    }

    public func toggleSaved(itemID: ClipboardItem.ID, undoManager: UndoManager? = nil) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              !items[index].isDeleted
        else {
            return
        }

        setSaved(itemID: itemID, isSaved: !items[index].isSaved, undoManager: undoManager)
    }

    private func setSaved(itemID: ClipboardItem.ID, isSaved: Bool, undoManager: UndoManager?) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              !items[index].isDeleted,
              items[index].isSaved != isSaved
        else {
            return
        }

        let previousValue = items[index].isSaved
        items[index].isSaved = isSaved
        items[index].updatedAt = Date()
        persist()
        analyticsRecorder?.record(.clipAction(isSaved ? .favoriteAdded : .favoriteRemoved))

        undoManager?.registerUndo(withTarget: self) { store in
            store.setSaved(itemID: itemID, isSaved: previousValue, undoManager: undoManager)
        }
        undoManager?.setActionName(isSaved ? "Favorite Clip" : "Unfavorite Clip")
    }

    public func rename(itemID: ClipboardItem.ID, title: String, undoManager: UndoManager? = nil) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let previousTitle = items[index].customTitle
        let normalizedTitle = ClipboardItem.normalizedTitle(title)
        guard previousTitle != normalizedTitle else {
            return
        }

        items[index].customTitle = normalizedTitle
        items[index].updatedAt = Date()
        persist()
        analyticsRecorder?.record(.clipAction(.renamed))

        undoManager?.registerUndo(withTarget: self) { store in
            store.rename(itemID: itemID, title: previousTitle ?? "", undoManager: undoManager)
        }
        undoManager?.setActionName("Rename Clip")
    }

    public func delete(itemID: ClipboardItem.ID, undoManager: UndoManager? = nil) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              !items[index].isDeleted
        else {
            return
        }

        setDeletedAt(itemID: itemID, deletedAt: Date(), undoManager: undoManager)
    }

    public func restore(itemID: ClipboardItem.ID, undoManager: UndoManager? = nil) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].isDeleted
        else {
            return
        }

        setDeletedAt(itemID: itemID, deletedAt: nil, undoManager: undoManager)
    }

    private func setDeletedAt(itemID: ClipboardItem.ID, deletedAt: Date?, undoManager: UndoManager?) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].deletedAt != deletedAt
        else {
            return
        }

        let previousDeletedAt = items[index].deletedAt
        items[index].deletedAt = deletedAt
        items[index].updatedAt = Date()

        if deletedAt == nil, items[index].kind == .image {
            scheduleTranscription(for: items[index])
        } else if deletedAt != nil {
            transcriptionTasks[itemID]?.cancel()
            transcriptionTasks[itemID] = nil
        }

        persist()
        analyticsRecorder?.record(.clipAction(deletedAt == nil ? .restored : .deleted))

        undoManager?.registerUndo(withTarget: self) { store in
            store.setDeletedAt(itemID: itemID, deletedAt: previousDeletedAt, undoManager: undoManager)
        }
        undoManager?.setActionName(deletedAt == nil ? "Restore Clip" : "Delete Clip")
    }

    public func copyPreferred(itemID: ClipboardItem.ID) {
        guard let item = item(id: itemID), !item.isDeleted else {
            return
        }

        switch item.kind {
        case .text:
            copyText(itemID: itemID, variant: item.hasRichText ? .rich : .plain, analyticsAction: .copy)
        case .image:
            copyImage(itemID: itemID, variant: .preferred)
        }
    }

    public func copyText(
        itemID: ClipboardItem.ID,
        variant: TextCopyVariant,
        analyticsAction: AnalyticsClipAction? = nil
    ) {
        guard let item = item(id: itemID), !item.isDeleted, item.kind == .text else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch variant {
        case .plain:
            if let plainText = item.plainText {
                pasteboard.setString(plainText, forType: .string)
            }
        case .rich:
            if let richTextFilename = item.richTextFilename,
               let data = storage.richTextData(filename: richTextFilename) {
                pasteboard.setData(data, forType: .rtf)
            }
            if let plainText = item.plainText {
                pasteboard.setString(plainText, forType: .string)
            }
        }

        monitor.acceptCurrentChangeCount()
        analyticsRecorder?.record(.clipAction(analyticsAction ?? (variant == .plain ? .copyPlainText : .copy)))
    }

    public func copyImage(itemID: ClipboardItem.ID, variant: ImageVariant) {
        guard let item = item(id: itemID),
              !item.isDeleted,
              item.kind == .image,
              let image = image(for: item, variant: variant)
        else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let pngData = image.pngData {
            pasteboard.setData(pngData, forType: .png)
        }
        if let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
        pasteboard.writeObjects([image])
        monitor.acceptCurrentChangeCount()
        analyticsRecorder?.record(.clipAction(variant == .original ? .copyOriginalImage : .copy))
    }

    public func image(for item: ClipboardItem, variant: ImageVariant) -> NSImage? {
        let filename: String?
        switch variant {
        case .preferred:
            filename = item.markedImageFilename ?? item.originalImageFilename
        case .original:
            filename = item.originalImageFilename
        case .marked:
            filename = item.markedImageFilename ?? item.originalImageFilename
        }

        guard let filename else {
            return nil
        }
        #if DEBUG
        let url = storage.url(filename: filename)
        let token = StartupTimingLogger.beginOnce(.firstPersistedImageLoad, "first persisted image load")
        let byteCount = token == nil ? nil : Self.fileSize(at: url)
        let image = storage.image(filename: filename)
        StartupTimingLogger.end(
            token,
            metadata: [
                "variant=\(variant)",
                StartupTimingLogger.metadata(for: image, filename: filename, byteCount: byteCount)
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        )
        return image
        #else
        return storage.image(filename: filename)
        #endif
    }

    public func imageURL(for item: ClipboardItem, variant: ImageVariant) -> URL? {
        let filename: String?
        switch variant {
        case .preferred:
            filename = item.markedImageFilename ?? item.originalImageFilename
        case .original:
            filename = item.originalImageFilename
        case .marked:
            filename = item.markedImageFilename ?? item.originalImageFilename
        }

        guard let filename else {
            return nil
        }
        return storage.url(filename: filename)
    }

    public func updateMarkups(itemID: ClipboardItem.ID, elements: [MarkupElement], undoManager: UndoManager? = nil) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              !items[index].isDeleted,
              items[index].kind == .image,
              let original = image(for: items[index], variant: .original)
        else {
            return
        }

        do {
            let previousElements = items[index].markups
            guard previousElements != elements else {
                return
            }

            items[index].markups = elements
            if elements.isEmpty {
                items[index].markedImageFilename = nil
            } else {
                let rendered = MarkupRenderer.render(original: original, elements: elements)
                items[index].markedImageFilename = try storage.saveImage(rendered, itemID: itemID, variant: "marked")
            }
            items[index].updatedAt = Date()
            persist()
            analyticsRecorder?.record(.clipAction(.markupSaved))

            undoManager?.registerUndo(withTarget: self) { store in
                store.updateMarkups(itemID: itemID, elements: previousElements, undoManager: undoManager)
            }
            undoManager?.setActionName("Update Markup")
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func availableExportFormats(itemID: ClipboardItem.ID) -> [ClipboardTransferFormat] {
        guard let item = item(id: itemID) else {
            return []
        }

        return ClipboardTransferPlanner.availableFormats(for: item)
    }

    public func defaultExportPlan(itemID: ClipboardItem.ID) -> ClipboardExportPlan? {
        guard let item = item(id: itemID),
              let format = ClipboardTransferPlanner.defaultFormat(for: item)
        else {
            return nil
        }

        return ClipboardTransferPlanner.exportPlan(for: item, format: format)
    }

    public func writeExport(itemID: ClipboardItem.ID, format: ClipboardTransferFormat, to url: URL) throws {
        guard let item = item(id: itemID), !item.isDeleted else {
            throw ClipboardTransferError.itemUnavailable
        }

        switch format {
        case .plainText:
            guard let plainText = item.plainText else {
                throw ClipboardTransferError.itemUnavailable
            }
            try plainText.write(to: url, atomically: true, encoding: .utf8)
        case .richText:
            guard let filename = item.richTextFilename,
                  let data = storage.richTextData(filename: filename)
            else {
                throw ClipboardTransferError.itemUnavailable
            }
            try data.write(to: url, options: .atomic)
        case .preferredImage:
            try writeImageExport(item: item, variant: .preferred, to: url)
        case .originalImage:
            try writeImageExport(item: item, variant: .original, to: url)
        }
        analyticsRecorder?.record(.clipAction(.exported))
    }

    public func sharingItems(itemID: ClipboardItem.ID) -> [Any] {
        guard let item = item(id: itemID), !item.isDeleted else {
            return []
        }

        switch item.kind {
        case .text:
            let items = item.plainText.map { [$0] } ?? []
            if !items.isEmpty {
                analyticsRecorder?.record(.clipAction(.shared))
            }
            return items
        case .image:
            let items = imageURL(for: item, variant: .preferred).map { [$0] } ?? []
            if !items.isEmpty {
                analyticsRecorder?.record(.clipAction(.shared))
            }
            return items
        }
    }

    public func itemProvider(itemID: ClipboardItem.ID) -> NSItemProvider? {
        guard let item = item(id: itemID), !item.isDeleted else {
            return nil
        }

        guard let format = ClipboardTransferPlanner.defaultFormat(for: item) else {
            return nil
        }

        let plan = ClipboardTransferPlanner.exportPlan(for: item, format: format)
        let provider = NSItemProvider()
        provider.suggestedName = URL(fileURLWithPath: plan.suggestedFilename).deletingPathExtension().lastPathComponent

        switch item.kind {
        case .text:
            switch format {
            case .richText:
                guard let filename = item.richTextFilename,
                      let data = storage.richTextData(filename: filename)
                else {
                    return nil
                }
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.rtf.identifier,
                    visibility: .all
                ) { completion in
                    completion(data, nil)
                    return nil
                }
            case .plainText:
                guard let plainText = item.plainText,
                      let data = plainText.data(using: .utf8)
                else {
                    return nil
                }
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.plainText.identifier,
                    visibility: .all
                ) { completion in
                    completion(data, nil)
                    return nil
                }
            case .preferredImage, .originalImage:
                return nil
            }
            return provider
        case .image:
            guard let url = imageURL(for: item, variant: .preferred) else {
                return nil
            }
            let imageProvider = NSItemProvider(contentsOf: url)
            imageProvider?.suggestedName = provider.suggestedName
            return imageProvider
        }
    }

    public func quickLook(itemID: ClipboardItem.ID, variant: ImageVariant) {
        guard let item = item(id: itemID),
              !item.isDeleted,
              let url = imageURL(for: item, variant: variant)
        else {
            return
        }
        QuickLookService.shared.preview(url: url)
        analyticsRecorder?.record(.clipAction(.quickLook))
    }

    private func record(_ capture: ClipboardCapture) {
        guard capture.fingerprint != items.first(where: { !$0.isDeleted })?.fingerprint else {
            return
        }

        do {
            let itemID = UUID()
            let now = Date()

            let item: ClipboardItem
            switch capture {
            case let .text(plainText, richRTF, fingerprint):
                let richTextFilename = try richRTF.map { try storage.saveRichText($0, itemID: itemID) }
                item = ClipboardItem(
                    id: itemID,
                    createdAt: now,
                    updatedAt: now,
                    kind: .text,
                    plainText: plainText,
                    richTextFilename: richTextFilename,
                    fingerprint: fingerprint
                )
            case let .image(image, fingerprint):
                let originalFilename = try storage.saveImage(image, itemID: itemID, variant: "original")
                item = ClipboardItem(
                    id: itemID,
                    createdAt: now,
                    updatedAt: now,
                    kind: .image,
                    originalImageFilename: originalFilename,
                    imageWidth: image.size.width,
                    imageHeight: image.size.height,
                    fingerprint: fingerprint
                )
            }

            items.insert(item, at: 0)
            persist()
            analyticsRecorder?.record(.clipCaptured(capture.analyticsKind))

            if item.kind == .image {
                scheduleTranscription(for: item)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func transcribePendingImages() {
        for item in items where !item.isDeleted && item.kind == .image && needsImageRecognition(item) {
            scheduleTranscription(for: item)
        }
    }

    private func scheduleTranscription(for item: ClipboardItem) {
        guard transcriptionTasks[item.id] == nil,
              !item.isDeleted,
              item.kind == .image,
              needsImageRecognition(item),
              let image = image(for: item, variant: .original)
        else {
            return
        }

        transcriptionTasks[item.id] = Task { [weak self] in
            let result = await ImageTextRecognizer.recognize(in: image)
            guard let self else {
                return
            }
            self.applyRecognitionResult(result, itemID: item.id)
        }
    }

    private func needsImageRecognition(_ item: ClipboardItem) -> Bool {
        item.imageTranscript == nil || item.thumbnailFocusRect == nil
    }

    private func applyRecognitionResult(_ result: ImageTextRecognitionResult, itemID: ClipboardItem.ID) {
        transcriptionTasks[itemID] = nil

        guard let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].kind == .image,
              !items[index].isDeleted,
              needsImageRecognition(items[index])
        else {
            return
        }

        if items[index].imageTranscript == nil {
            items[index].imageTranscript = result.transcript ?? ""
        }
        if items[index].thumbnailFocusRect == nil {
            items[index].thumbnailFocusRect = result.thumbnailFocusRect ?? .defaultThumbnailFocus
        }
        items[index].updatedAt = Date()
        persist()
    }

    private func startPurgeTimer() {
        guard purgeTimer == nil else {
            return
        }

        purgeTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.purgeExpiredDeletedItems()
            }
        }
    }

    private func purgeExpiredDeletedItems(now: Date = Date()) {
        do {
            let retainedItems = try storage.purgeExpiredDeletedItems(from: items, now: now)
            guard retainedItems.count != items.count else {
                return
            }

            let retainedIDs = Set(retainedItems.map(\.id))
            let removedIDs = Set(items.map(\.id)).subtracting(retainedIDs)
            for itemID in removedIDs {
                transcriptionTasks[itemID]?.cancel()
                transcriptionTasks[itemID] = nil
            }

            items = retainedItems
            try storage.saveItems(retainedItems)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func persist() {
        do {
            try storage.saveItems(items)
        } catch {
            lastError = error.localizedDescription
        }
    }

    #if DEBUG
    private static func fileSize(at url: URL) -> Int64? {
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }

    private static func startupStorageLocationKind(for url: URL) -> String {
        let path = url.standardizedFileURL.path.lowercased()
        if path.contains("/library/cloudstorage/dropbox") {
            return "dropbox"
        }
        if path.contains("/library/cloudstorage/googledrive") {
            return "googleDrive"
        }
        if path.contains("/library/mobile documents/com~apple~clouddocs") {
            return "iCloudDrive"
        }
        if path.contains("/library/application support/clipboardmarkup") {
            return "applicationSupport"
        }
        return "custom"
    }
    #endif

    private func writeImageExport(item: ClipboardItem, variant: ImageVariant, to url: URL) throws {
        guard let image = image(for: item, variant: variant),
              let pngData = image.pngData
        else {
            throw ClipboardTransferError.itemUnavailable
        }

        try pngData.write(to: url, options: .atomic)
    }
}

public enum ClipboardTransferError: LocalizedError {
    case itemUnavailable

    public var errorDescription: String? {
        switch self {
        case .itemUnavailable:
            "The selected clip is no longer available."
        }
    }
}
