import CoreGraphics
import Foundation

struct ArrowGeometry {
    var tip: CGPoint
    var baseCenter: CGPoint
    var leftBase: CGPoint
    var rightBase: CGPoint
    var shaftEnd: CGPoint

    static func make(start: CGPoint, end: CGPoint, lineWidth: CGFloat) -> ArrowGeometry {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)

        guard length > 0 else {
            return ArrowGeometry(
                tip: end,
                baseCenter: end,
                leftBase: end,
                rightBase: end,
                shaftEnd: end
            )
        }

        let direction = CGPoint(x: dx / length, y: dy / length)
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let requestedHeadLength = max(lineWidth * 4.2, 20)
        let maxHeadLength = max(lineWidth * 2.5, length * 0.45)
        let headLength = min(requestedHeadLength, maxHeadLength)
        let halfWidth = max(lineWidth * 1.9, headLength * 0.34)
        let baseCenter = CGPoint(
            x: end.x - direction.x * headLength,
            y: end.y - direction.y * headLength
        )
        let overlap = min(lineWidth * 0.8, headLength * 0.25)

        return ArrowGeometry(
            tip: end,
            baseCenter: baseCenter,
            leftBase: CGPoint(
                x: baseCenter.x + normal.x * halfWidth,
                y: baseCenter.y + normal.y * halfWidth
            ),
            rightBase: CGPoint(
                x: baseCenter.x - normal.x * halfWidth,
                y: baseCenter.y - normal.y * halfWidth
            ),
            shaftEnd: CGPoint(
                x: baseCenter.x + direction.x * overlap,
                y: baseCenter.y + direction.y * overlap
            )
        )
    }
}
