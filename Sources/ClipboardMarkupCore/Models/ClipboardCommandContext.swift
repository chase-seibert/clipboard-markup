import SwiftUI

public struct ClipboardCommandContext {
    public let item: ClipboardItem?
    public let state: ClipboardCommandState
    public let copy: () -> Void
    public let copyAlternate: () -> Void
    public let markup: () -> Void
    public let quickLook: () -> Void
    public let rename: () -> Void
    public let toggleFavorite: () -> Void
    public let delete: () -> Void
    public let restore: () -> Void

    public init(
        item: ClipboardItem?,
        copy: @escaping () -> Void,
        copyAlternate: @escaping () -> Void,
        markup: @escaping () -> Void,
        quickLook: @escaping () -> Void,
        rename: @escaping () -> Void,
        toggleFavorite: @escaping () -> Void,
        delete: @escaping () -> Void,
        restore: @escaping () -> Void
    ) {
        self.item = item
        self.state = ClipboardCommandState(item: item)
        self.copy = copy
        self.copyAlternate = copyAlternate
        self.markup = markup
        self.quickLook = quickLook
        self.rename = rename
        self.toggleFavorite = toggleFavorite
        self.delete = delete
        self.restore = restore
    }
}

private struct ClipboardCommandContextKey: FocusedValueKey {
    typealias Value = ClipboardCommandContext
}

public extension FocusedValues {
    var clipboardCommandContext: ClipboardCommandContext? {
        get { self[ClipboardCommandContextKey.self] }
        set { self[ClipboardCommandContextKey.self] = newValue }
    }
}
