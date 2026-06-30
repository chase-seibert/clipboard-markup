import Foundation

public enum LibraryFilter: String, CaseIterable, Identifiable, Hashable {
    case images
    case text
    case allClips
    case favorites

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .images:
            "Images"
        case .text:
            "Text"
        case .allClips:
            "All Clips"
        case .favorites:
            "Favorites"
        }
    }

    public var systemImage: String {
        switch self {
        case .images:
            "photo"
        case .text:
            "doc.text"
        case .allClips:
            "doc.on.clipboard"
        case .favorites:
            "star"
        }
    }

    public var listSectionTitle: String {
        switch self {
        case .allClips:
            "Recent"
        default:
            title
        }
    }

    public var emptyTitle: String {
        switch self {
        case .images:
            "No Images"
        case .text:
            "No Text"
        case .allClips:
            "No Clips"
        case .favorites:
            "No Favorites"
        }
    }

    public func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .images:
            item.kind == .image
        case .text:
            item.kind == .text
        case .allClips:
            true
        case .favorites:
            item.isSaved
        }
    }
}
