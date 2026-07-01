import Foundation

public struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    public static let deletedItemRetentionInterval: TimeInterval = 30 * 24 * 60 * 60

    public enum Kind: String, Codable {
        case text
        case image
    }

    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var kind: Kind
    public var plainText: String?
    public var richTextFilename: String?
    public var originalImageFilename: String?
    public var markedImageFilename: String?
    public var imageWidth: Double?
    public var imageHeight: Double?
    public var customTitle: String?
    public var imageTranscript: String?
    public var thumbnailFocusRect: NormalizedRect?
    public var markups: [MarkupElement]
    public var isSaved: Bool
    public var fingerprint: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        kind: Kind,
        plainText: String? = nil,
        richTextFilename: String? = nil,
        originalImageFilename: String? = nil,
        markedImageFilename: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        customTitle: String? = nil,
        imageTranscript: String? = nil,
        thumbnailFocusRect: NormalizedRect? = nil,
        markups: [MarkupElement] = [],
        isSaved: Bool = false,
        fingerprint: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.kind = kind
        self.plainText = plainText
        self.richTextFilename = richTextFilename
        self.originalImageFilename = originalImageFilename
        self.markedImageFilename = markedImageFilename
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.customTitle = Self.normalizedTitle(customTitle)
        self.imageTranscript = Self.normalizedTranscript(imageTranscript)
        self.thumbnailFocusRect = thumbnailFocusRect
        self.markups = markups
        self.isSaved = isSaved
        self.fingerprint = fingerprint
    }

    public var hasRichText: Bool {
        richTextFilename != nil
    }

    public var isDeleted: Bool {
        deletedAt != nil
    }

    public var hasMarkedImage: Bool {
        markedImageFilename != nil
    }

    public var hasCustomTitle: Bool {
        Self.normalizedTitle(customTitle) != nil
    }

    public var title: String {
        if let customTitle = Self.normalizedTitle(customTitle) {
            return customTitle
        }

        return automaticTitle
    }

    public var automaticTitle: String {
        switch kind {
        case .text:
            let text = plainText?
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? "Text" : Self.limitedTitle(text)
        case .image:
            if let transcriptTitle = Self.title(fromTranscript: imageTranscript) {
                return transcriptTitle
            }
            if let width = imageWidth, let height = imageHeight {
                return "Image \(Int(width)) x \(Int(height))"
            }
            return "Image"
        }
    }

    public var subtitle: String {
        switch kind {
        case .text:
            hasRichText ? "Rich text" : "Plain text"
        case .image:
            hasMarkedImage ? "Marked up image" : "Original image"
        }
    }

    public var searchableText: String {
        [
            title,
            plainText,
            imageTranscript
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    public func matchesSearch(_ query: String) -> Bool {
        let tokens = Self.searchTokens(from: query)
        guard !tokens.isEmpty else {
            return true
        }

        let haystack = Self.normalizedSearchText(searchableText)
        return tokens.allSatisfy { haystack.contains($0) }
    }

    public func shouldPermanentlyDelete(asOf date: Date) -> Bool {
        guard let deletedAt else {
            return false
        }

        return date.timeIntervalSince(deletedAt) >= Self.deletedItemRetentionInterval
    }

    public static func normalizedTitle(_ title: String?) -> String? {
        guard let title else {
            return nil
        }

        let normalized = title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : Self.limitedTitle(normalized)
    }

    public static func normalizedTranscript(_ transcript: String?) -> String? {
        guard let transcript else {
            return nil
        }

        return transcript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func title(fromTranscript transcript: String?) -> String? {
        guard let normalized = normalizedTranscript(transcript), !normalized.isEmpty else {
            return nil
        }

        return Self.limitedTitle(normalized)
    }

    private static func searchTokens(from query: String) -> [String] {
        normalizedSearchText(query)
            .split(separator: " ")
            .map(String.init)
    }

    private static func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func limitedTitle(_ title: String, limit: Int = 80) -> String {
        guard title.count > limit else {
            return title
        }

        let prefix = title.prefix(limit)
        guard let wordBoundary = prefix.lastIndex(where: { $0.isWhitespace }) else {
            return String(prefix)
        }

        return String(prefix[..<wordBoundary])
    }
}
