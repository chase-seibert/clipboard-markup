import AppKit
import Foundation

struct ClipboardStorage {
    let rootURL: URL
    let mediaURL: URL
    let manifestURL: URL

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.rootURL = applicationSupport.appendingPathComponent("ClipboardMarkup", isDirectory: true)
        self.mediaURL = rootURL.appendingPathComponent("Media", isDirectory: true)
        self.manifestURL = rootURL.appendingPathComponent("entries.json")
    }

    func loadItems() throws -> [ClipboardItem] {
        try ensureDirectories()
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return []
        }

        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder.clipboardMarkup.decode([ClipboardItem].self, from: data)
    }

    func saveItems(_ items: [ClipboardItem]) throws {
        try ensureDirectories()
        let data = try JSONEncoder.clipboardMarkup.encode(items)
        try data.write(to: manifestURL, options: .atomic)
    }

    func saveRichText(_ data: Data, itemID: UUID) throws -> String {
        try ensureDirectories()
        let filename = "\(itemID.uuidString)-rich.rtf"
        try data.write(to: mediaURL.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    func saveImage(_ image: NSImage, itemID: UUID, variant: String) throws -> String {
        try ensureDirectories()
        guard let data = image.pngData else {
            throw ClipboardStorageError.imageEncodingFailed
        }
        let filename = "\(itemID.uuidString)-\(variant).png"
        try data.write(to: mediaURL.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    func richTextData(filename: String) -> Data? {
        try? Data(contentsOf: mediaURL.appendingPathComponent(filename))
    }

    func image(filename: String) -> NSImage? {
        NSImage(contentsOf: mediaURL.appendingPathComponent(filename))
    }

    func url(filename: String) -> URL {
        mediaURL.appendingPathComponent(filename)
    }

    private func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)
    }
}

enum ClipboardStorageError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            "Unable to encode image as PNG."
        }
    }
}

private extension JSONEncoder {
    static var clipboardMarkup: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var clipboardMarkup: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
