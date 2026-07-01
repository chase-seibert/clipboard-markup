import Foundation

public enum LibraryFilter: String, CaseIterable, Identifiable, Hashable {
    case images
    case text
    case allClips
    case favorites
    case deleted

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
        case .deleted:
            "Deleted Items"
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
        case .deleted:
            "trash"
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
        case .deleted:
            "No Deleted Items"
        }
    }

    public func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .images:
            !item.isDeleted && item.kind == .image
        case .text:
            !item.isDeleted && item.kind == .text
        case .allClips:
            !item.isDeleted
        case .favorites:
            !item.isDeleted && item.isSaved
        case .deleted:
            item.isDeleted
        }
    }
}
