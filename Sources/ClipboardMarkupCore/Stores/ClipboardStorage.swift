import AppKit
import Foundation

struct ClipboardStorage {
    let rootURL: URL
    let mediaURL: URL
    let manifestURL: URL
    let agentGuideURL: URL

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.rootURL = applicationSupport.appendingPathComponent("ClipboardMarkup", isDirectory: true)
        self.mediaURL = rootURL.appendingPathComponent("Media", isDirectory: true)
        self.manifestURL = rootURL.appendingPathComponent("entries.json")
        self.agentGuideURL = rootURL.appendingPathComponent("AGENTS.md")
    }

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.mediaURL = rootURL.appendingPathComponent("Media", isDirectory: true)
        self.manifestURL = rootURL.appendingPathComponent("entries.json")
        self.agentGuideURL = rootURL.appendingPathComponent("AGENTS.md")
    }

    var agentPromptSnippet: String {
        """
        Retrieve recent clipboard contents by looking at the AGENTS.md file at \(agentGuideURL.path). This could be useful to generate more context on any work that I've done recently. You can look up contents by type and date range.
        """
    }

    var agentGuideContents: String {
        """
        # Clipboard Markup Data

        This directory stores local Clipboard Markup data in a format that coding agents and LLM tools can inspect.

        ## Important Paths

        - Data directory: `\(rootURL.path)`
        - Manifest: `\(manifestURL.path)`
        - Media directory: `\(mediaURL.path)`

        ## How To Load Clipboard History

        1. Read `entries.json` as a JSON array.
        2. Each entry is a clipboard item. Important fields include:
           - `id`: stable UUID for the entry.
           - `kind`: `text` or `image`.
           - `createdAt`, `updatedAt`, `deletedAt`: ISO-8601 timestamps. `deletedAt` is absent or null for active entries.
           - `plainText`: copied text content, when available.
           - `richTextFilename`: RTF payload filename, when available.
           - `originalImageFilename`: original image or screenshot PNG filename.
           - `markedImageFilename`: marked-up image PNG filename, when present.
           - `customTitle`: user-supplied title, when present.
           - `imageTranscript`: local OCR text extracted from the image, when present.
           - `isSaved`: favorite/bookmark flag.
        3. Resolve media filenames by joining the filename with the `Media` directory. Do not infer other directories.
        4. For an image entry's preferred display image, use `markedImageFilename` when present; otherwise use `originalImageFilename`.
        5. For an image entry's clean source image, use `originalImageFilename`.
        6. For rich text, read `richTextFilename` from `Media` as RTF.
        7. Ignore entries with `deletedAt` unless the user specifically asks for deleted items.

        ## Safety

        Treat this directory as application data. Read files freely when the user asks you to inspect clipboard history, but do not edit `entries.json`, delete media, or rewrite assets unless the user explicitly asks for a data repair or migration.

        ## Prompt Snippet

        \(agentPromptSnippet)
        """
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

    func purgeExpiredDeletedItems(
        from items: [ClipboardItem],
        now: Date = Date()
    ) throws -> [ClipboardItem] {
        var keptItems: [ClipboardItem] = []

        for item in items {
            if item.shouldPermanentlyDelete(asOf: now) {
                try deleteMedia(for: item)
            } else {
                keptItems.append(item)
            }
        }

        return keptItems
    }

    func ensureAgentGuide() throws {
        try ensureDirectories()
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

    func deleteMedia(for item: ClipboardItem) throws {
        let filenames = Set([
            item.richTextFilename,
            item.originalImageFilename,
            item.markedImageFilename
        ].compactMap { $0 })

        for filename in filenames {
            let fileURL = mediaURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    private func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)
        try writeAgentGuideIfNeeded()
    }

    private func writeAgentGuideIfNeeded() throws {
        let contents = agentGuideContents
        if let existingContents = try? String(contentsOf: agentGuideURL), existingContents == contents {
            return
        }

        try contents.write(to: agentGuideURL, atomically: true, encoding: .utf8)
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
