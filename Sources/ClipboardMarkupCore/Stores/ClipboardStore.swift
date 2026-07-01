import AppKit
import Combine
import Foundation

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

    private let storage: ClipboardStorage
    private let monitor: PasteboardMonitor
    private var transcriptionTasks: [ClipboardItem.ID: Task<Void, Never>] = [:]
    private var purgeTimer: Timer?

    public init() {
        self.storage = ClipboardStorage()
        self.monitor = PasteboardMonitor()

        do {
            let loadedItems = try storage.loadItems().sorted { $0.createdAt > $1.createdAt }
            let retainedItems = try storage.purgeExpiredDeletedItems(from: loadedItems)
            self.items = retainedItems

            if retainedItems.count != loadedItems.count {
                try storage.saveItems(retainedItems)
            }
        } catch {
            self.lastError = error.localizedDescription
            self.items = []
        }

        monitor.onCapture = { [weak self] capture in
            self?.record(capture)
        }

        transcribePendingImages()
    }

    public var savedItems: [ClipboardItem] {
        items.filter { $0.isSaved && !$0.isDeleted }
    }

    public func startMonitoring() {
        monitor.start()
        purgeExpiredDeletedItems()
        startPurgeTimer()
    }

    public func item(id: ClipboardItem.ID?) -> ClipboardItem? {
        guard let id else {
            return nil
        }
        return items.first { $0.id == id }
    }

    public func toggleSaved(itemID: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              !items[index].isDeleted
        else {
            return
        }
        items[index].isSaved.toggle()
        items[index].updatedAt = Date()
        persist()
    }

    public func rename(itemID: ClipboardItem.ID, title: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        items[index].customTitle = ClipboardItem.normalizedTitle(title)
        items[index].updatedAt = Date()
        persist()
    }

    public func delete(itemID: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              !items[index].isDeleted
        else {
            return
        }

        let now = Date()
        items[index].deletedAt = now
        items[index].updatedAt = now
        transcriptionTasks[itemID]?.cancel()
        transcriptionTasks[itemID] = nil
        persist()
    }

    public func restore(itemID: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].isDeleted
        else {
            return
        }

        items[index].deletedAt = nil
        items[index].updatedAt = Date()
        persist()

        if items[index].kind == .image {
            scheduleTranscription(for: items[index])
        }
    }

    public func copyPreferred(itemID: ClipboardItem.ID) {
        guard let item = item(id: itemID), !item.isDeleted else {
            return
        }

        switch item.kind {
        case .text:
            copyText(itemID: itemID, variant: item.hasRichText ? .rich : .plain)
        case .image:
            copyImage(itemID: itemID, variant: .preferred)
        }
    }

    public func copyText(itemID: ClipboardItem.ID, variant: TextCopyVariant) {
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
        return storage.image(filename: filename)
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

    public func updateMarkups(itemID: ClipboardItem.ID, elements: [MarkupElement]) {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              !items[index].isDeleted,
              items[index].kind == .image,
              let original = image(for: items[index], variant: .original)
        else {
            return
        }

        do {
            items[index].markups = elements
            if elements.isEmpty {
                items[index].markedImageFilename = nil
            } else {
                let rendered = MarkupRenderer.render(original: original, elements: elements)
                items[index].markedImageFilename = try storage.saveImage(rendered, itemID: itemID, variant: "marked")
            }
            items[index].updatedAt = Date()
            persist()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func openInPreview(itemID: ClipboardItem.ID, variant: ImageVariant) {
        guard let item = item(id: itemID),
              !item.isDeleted,
              let url = imageURL(for: item, variant: variant)
        else {
            return
        }
        PreviewService.open(url: url)
    }

    public func quickLook(itemID: ClipboardItem.ID, variant: ImageVariant) {
        guard let item = item(id: itemID),
              !item.isDeleted,
              let url = imageURL(for: item, variant: variant)
        else {
            return
        }
        QuickLookService.shared.preview(url: url)
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
}
