import AppKit

public enum MarkupRenderer {
    public static func render(original: NSImage, elements: [MarkupElement]) -> NSImage {
        let size = original.size
        let rendered = NSImage(size: size)

        rendered.lockFocus()
        original.draw(in: CGRect(origin: .zero, size: size))

        for element in elements {
            draw(element: element, in: size)
        }

        rendered.unlockFocus()
        return rendered
    }

    private static func draw(element: MarkupElement, in size: CGSize) {
        let color = NSColor(hex: element.colorHex) ?? .systemRed
        color.setStroke()
        color.setFill()

        switch element.kind {
        case .arrow:
            drawArrow(element: element, size: size)
        case .rectangle:
            drawRectangle(element: element, size: size)
        case .text:
            drawText(element: element, size: size, color: color)
        }
    }

    private static func drawArrow(element: MarkupElement, size: CGSize) {
        let start = imagePoint(element.start, size: size)
        let end = imagePoint(element.end, size: size)
        let lineWidth = CGFloat(element.lineWidth)
        let geometry = ArrowGeometry.make(start: start, end: end, lineWidth: lineWidth)
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: geometry.shaftEnd)
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.stroke()

        let head = NSBezierPath()
        head.move(to: geometry.tip)
        head.line(to: geometry.leftBase)
        head.line(to: geometry.rightBase)
        head.close()
        head.fill()
    }

    private static func drawRectangle(element: MarkupElement, size: CGSize) {
        let rect = imageRect(from: element.start, to: element.end, size: size)
        let path = NSBezierPath(rect: rect)
        path.lineWidth = CGFloat(element.lineWidth)
        path.stroke()
    }

    private static func drawText(element: MarkupElement, size: CGSize, color: NSColor) {
        let font = NSFont(name: element.fontName, size: CGFloat(element.fontSize))
            ?? .systemFont(ofSize: CGFloat(element.fontSize), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attributed = NSAttributedString(string: element.text, attributes: attributes)
        let textSize = attributed.size()
        let center = imagePoint(element.start, size: size)
        let rect = CGRect(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        attributed.draw(in: rect)
    }

    private static func imagePoint(_ point: NormalizedPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: (1 - point.y) * size.height
        )
    }

    private static func imageRect(from start: NormalizedPoint, to end: NormalizedPoint, size: CGSize) -> CGRect {
        let minX = min(start.x, end.x) * size.width
        let maxX = max(start.x, end.x) * size.width
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        return CGRect(
            x: minX,
            y: (1 - maxY) * size.height,
            width: maxX - minX,
            height: (maxY - minY) * size.height
        )
    }
}
