import CoreGraphics
@testable import ClipboardMarkupCore
import XCTest

final class ArrowGeometryTests: XCTestCase {
    func testArrowHeadBaseIsCenteredOnShaftAxis() {
        let start = CGPoint(x: 120, y: 460)
        let end = CGPoint(x: 760, y: 210)
        let geometry = ArrowGeometry.make(start: start, end: end, lineWidth: 16)

        let baseMidpoint = CGPoint(
            x: (geometry.leftBase.x + geometry.rightBase.x) / 2,
            y: (geometry.leftBase.y + geometry.rightBase.y) / 2
        )

        XCTAssertEqual(baseMidpoint.x, geometry.baseCenter.x, accuracy: 0.001)
        XCTAssertEqual(baseMidpoint.y, geometry.baseCenter.y, accuracy: 0.001)
        XCTAssertEqual(crossProduct(start: start, end: end, point: geometry.baseCenter), 0, accuracy: 0.001)
        XCTAssertEqual(crossProduct(start: start, end: end, point: geometry.shaftEnd), 0, accuracy: 0.001)
    }

    func testShaftEndsInsideArrowHead() {
        let start = CGPoint(x: 20, y: 20)
        let end = CGPoint(x: 220, y: 140)
        let geometry = ArrowGeometry.make(start: start, end: end, lineWidth: 12)

        XCTAssertLessThan(distance(geometry.shaftEnd, end), distance(geometry.baseCenter, end))
    }

    private func crossProduct(start: CGPoint, end: CGPoint, point: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let pointDX = point.x - start.x
        let pointDY = point.y - start.y
        return dx * pointDY - dy * pointDX
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
