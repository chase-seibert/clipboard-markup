import Foundation

public struct ClipboardCommandState: Equatable {
    public let item: ClipboardItem?

    public init(item: ClipboardItem?) {
        self.item = item
    }

    public var hasSelection: Bool {
        item != nil
    }

    public var canCopy: Bool {
        guard let item else {
            return false
        }
        return !item.isDeleted
    }

    public var canCopyPlainText: Bool {
        guard let item else {
            return false
        }
        return !item.isDeleted && item.kind == .text && item.hasRichText
    }

    public var canCopyOriginalImage: Bool {
        guard let item else {
            return false
        }
        return !item.isDeleted && item.kind == .image
    }

    public var canMarkup: Bool {
        guard let item else {
            return false
        }
        return !item.isDeleted && item.kind == .image
    }

    public var canQuickLook: Bool {
        canMarkup
    }

    public var canRename: Bool {
        item != nil
    }

    public var canToggleFavorite: Bool {
        guard let item else {
            return false
        }
        return !item.isDeleted
    }

    public var canDelete: Bool {
        guard let item else {
            return false
        }
        return !item.isDeleted
    }

    public var canRestore: Bool {
        item?.isDeleted == true
    }

    public var canExport: Bool {
        guard let item else {
            return false
        }
        return !item.isDeleted
    }

    public var canShare: Bool {
        canExport
    }
}
