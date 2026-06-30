import Foundation

public enum MenuBarTitleFormatter {
    public static func title(for item: ClipboardItem, limit: Int = 30) -> String {
        let rawTitle: String
        switch item.kind {
        case .text:
            rawTitle = item.title
        case .image:
            rawTitle = item.title
        }

        let fallback = rawTitle.isEmpty ? item.title : rawTitle
        return truncate(fallback, limit: limit)
    }

    public static func truncate(_ value: String, limit: Int = 30) -> String {
        guard value.count > limit, limit > 3 else {
            return value
        }

        return "\(value.prefix(limit - 3))..."
    }
}
