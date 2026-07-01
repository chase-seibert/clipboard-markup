import AppKit
import Foundation
import UniformTypeIdentifiers

public enum ClipboardTransferFormat: String, CaseIterable, Hashable {
    case plainText
    case richText
    case preferredImage
    case originalImage
}

public struct ClipboardExportPlan: Equatable {
    public let format: ClipboardTransferFormat
    public let suggestedFilename: String
    public let contentType: UTType

    public init(format: ClipboardTransferFormat, suggestedFilename: String, contentType: UTType) {
        self.format = format
        self.suggestedFilename = suggestedFilename
        self.contentType = contentType
    }
}

public enum ClipboardTransferPlanner {
    public static func availableFormats(for item: ClipboardItem) -> [ClipboardTransferFormat] {
        guard !item.isDeleted else {
            return []
        }

        switch item.kind {
        case .text:
            return item.hasRichText ? [.richText, .plainText] : [.plainText]
        case .image:
            return [.preferredImage, .originalImage]
        }
    }

    public static func defaultFormat(for item: ClipboardItem) -> ClipboardTransferFormat? {
        availableFormats(for: item).first
    }

    public static func exportPlan(for item: ClipboardItem, format: ClipboardTransferFormat) -> ClipboardExportPlan {
        let baseName = sanitizedFilenameBase(from: item.title)

        switch format {
        case .plainText:
            return ClipboardExportPlan(format: format, suggestedFilename: "\(baseName).txt", contentType: .plainText)
        case .richText:
            return ClipboardExportPlan(format: format, suggestedFilename: "\(baseName).rtf", contentType: .rtf)
        case .preferredImage:
            return ClipboardExportPlan(format: format, suggestedFilename: "\(baseName).png", contentType: .png)
        case .originalImage:
            return ClipboardExportPlan(format: format, suggestedFilename: "\(baseName)-original.png", contentType: .png)
        }
    }

    private static func sanitizedFilenameBase(from title: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = title
            .components(separatedBy: invalidCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let limited = cleaned.isEmpty ? "Clipboard Markup Clip" : String(cleaned.prefix(80))
        return limited.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
