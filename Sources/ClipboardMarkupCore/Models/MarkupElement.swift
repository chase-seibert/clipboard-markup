import Foundation

public enum MarkupTool: String, CaseIterable, Identifiable {
    case select
    case arrow
    case rectangle
    case text

    public var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .select:
            "cursorarrow"
        case .arrow:
            "arrow.up.right"
        case .rectangle:
            "rectangle"
        case .text:
            "textformat"
        }
    }

    var title: String {
        switch self {
        case .select:
            "Select"
        case .arrow:
            "Arrow"
        case .rectangle:
            "Rectangle"
        case .text:
            "Text"
        }
    }
}

public struct NormalizedPoint: Codable, Equatable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x.clamped(to: 0...1)
        self.y = y.clamped(to: 0...1)
    }

    public func translatedBy(dx: Double, dy: Double) -> NormalizedPoint {
        NormalizedPoint(x: x + dx, y: y + dy)
    }
}

public struct MarkupElement: Identifiable, Codable, Equatable, Hashable {
    public enum Kind: String, Codable {
        case arrow
        case rectangle
        case text
    }

    public var id: UUID
    public var kind: Kind
    public var start: NormalizedPoint
    public var end: NormalizedPoint
    public var text: String
    public var colorHex: String
    public var lineWidth: Double
    public var fontName: String
    public var fontSize: Double

    public init(
        id: UUID = UUID(),
        kind: Kind,
        start: NormalizedPoint,
        end: NormalizedPoint,
        text: String = "",
        colorHex: String = "#FF3B30",
        lineWidth: Double = 8,
        fontName: String = "Helvetica Neue",
        fontSize: Double = 36
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.text = text
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.fontName = fontName
        self.fontSize = fontSize
    }

    public mutating func translate(dx: Double, dy: Double) {
        start = start.translatedBy(dx: dx, dy: dy)
        end = end.translatedBy(dx: dx, dy: dy)
    }
}
