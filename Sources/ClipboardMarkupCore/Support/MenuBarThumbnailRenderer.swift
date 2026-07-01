import AppKit
import CoreGraphics

enum MenuBarThumbnailRenderer {
    static let defaultSize = NSSize(width: 18, height: 18)

    static func thumbnail(for image: NSImage?, size: NSSize = defaultSize) -> NSImage? {
        guard let image else {
            return nil
        }

        return thumbnail(for: image, size: size)
    }

    static func thumbnail(for image: NSImage, size: NSSize = defaultSize) -> NSImage? {
        guard image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 else {
            return nil
        }

        let targetRect = NSRect(origin: .zero, size: size)
        let sourceRect = aspectFillSourceRect(imageSize: image.size, targetSize: size)
        let output = NSImage(size: size)

        output.lockFocus()
        defer { output.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.setFill()
        targetRect.fill()

        let clipPath = NSBezierPath(roundedRect: targetRect, xRadius: 3, yRadius: 3)
        clipPath.addClip()

        NSColor.textBackgroundColor.setFill()
        targetRect.fill()

        image.draw(
            in: targetRect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )

        NSColor.separatorColor.withAlphaComponent(0.70).setStroke()
        clipPath.lineWidth = 1
        clipPath.stroke()

        output.isTemplate = false
        return output
    }

    static func aspectFillSourceRect(imageSize: NSSize, targetSize: NSSize) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0, targetSize.width > 0, targetSize.height > 0 else {
            return .zero
        }

        let imageAspect = imageSize.width / imageSize.height
        let targetAspect = targetSize.width / targetSize.height

        if imageAspect > targetAspect {
            let width = imageSize.height * targetAspect
            return NSRect(
                x: (imageSize.width - width) / 2,
                y: 0,
                width: width,
                height: imageSize.height
            )
        }

        let height = imageSize.width / targetAspect
        return NSRect(
            x: 0,
            y: (imageSize.height - height) / 2,
            width: imageSize.width,
            height: height
        )
    }
}
