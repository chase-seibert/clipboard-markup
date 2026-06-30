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

    public init() {
        self.storage = ClipboardStorage()
        self.monitor = PasteboardMonitor()

        do {
            self.items = try storage.loadItems().sorted { $0.createdAt > $1.createdAt }
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
        items.filter(\.isSaved)
    }

    public func startMonitoring() {
        monitor.start()
    }

    public func item(id: ClipboardItem.ID?) -> ClipboardItem? {
        guard let id else {
            return nil
        }
        return items.first { $0.id == id }
    }

    public func toggleSaved(itemID: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
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

    public func copyPreferred(itemID: ClipboardItem.ID) {
        guard let item = item(id: itemID) else {
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
        guard let item = item(id: itemID), item.kind == .text else {
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
              let url = imageURL(for: item, variant: variant)
        else {
            return
        }
        PreviewService.open(url: url)
    }

    public func quickLook(itemID: ClipboardItem.ID, variant: ImageVariant) {
        guard let item = item(id: itemID),
              let url = imageURL(for: item, variant: variant)
        else {
            return
        }
        QuickLookService.shared.preview(url: url)
    }

    private func record(_ capture: ClipboardCapture) {
        guard capture.fingerprint != items.first?.fingerprint else {
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
        for item in items where item.kind == .image && item.imageTranscript == nil {
            scheduleTranscription(for: item)
        }
    }

    private func scheduleTranscription(for item: ClipboardItem) {
        guard transcriptionTasks[item.id] == nil,
              item.kind == .image,
              item.imageTranscript == nil,
              let image = image(for: item, variant: .original)
        else {
            return
        }

        transcriptionTasks[item.id] = Task { [weak self] in
            let transcript = await ImageTextRecognizer.transcript(from: image) ?? ""
            guard let self else {
                return
            }
            self.applyTranscript(transcript, itemID: item.id)
        }
    }

    private func applyTranscript(_ transcript: String, itemID: ClipboardItem.ID) {
        transcriptionTasks[itemID] = nil

        guard let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].kind == .image,
              items[index].imageTranscript == nil
        else {
            return
        }

        items[index].imageTranscript = ClipboardItem.normalizedTranscript(transcript) ?? ""
        items[index].updatedAt = Date()
        persist()
    }

    private func persist() {
        do {
            try storage.saveItems(items)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
