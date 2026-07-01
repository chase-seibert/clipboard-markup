import AppKit

extension NSImage {
    func cropped(to normalizedRect: NormalizedRect) -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: CGFloat(normalizedRect.x) * imageWidth,
            y: CGFloat(normalizedRect.y) * imageHeight,
            width: CGFloat(normalizedRect.width) * imageWidth,
            height: CGFloat(normalizedRect.height) * imageHeight
        ).integral.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        guard cropRect.width > 0,
              cropRect.height > 0,
              let cropped = cgImage.cropping(to: cropRect)
        else {
            return nil
        }

        return NSImage(
            cgImage: cropped,
            size: NSSize(width: cropped.width, height: cropped.height)
        )
    }
}
