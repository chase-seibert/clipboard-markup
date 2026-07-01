import Foundation

public struct NormalizedRect: Codable, Equatable, Hashable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        let clampedWidth = width.clamped(to: 0.05...1)
        let clampedHeight = height.clamped(to: 0.05...1)

        self.width = clampedWidth
        self.height = clampedHeight
        self.x = x.clamped(to: 0...(1 - clampedWidth))
        self.y = y.clamped(to: 0...(1 - clampedHeight))
    }

    public static let defaultThumbnailFocus = NormalizedRect(
        x: 0,
        y: 0.18,
        width: 1,
        height: 0.28
    )
}
