import AppKit

enum PasteboardWriter {
    @discardableResult
    static func writeImage(_ image: NSImage, to pasteboard: NSPasteboard = .general) -> Bool {
        let item = NSPasteboardItem()

        if let pngData = image.pngData {
            item.setData(pngData, forType: .png)
        }
        if let tiffData = image.tiffRepresentation {
            item.setData(tiffData, forType: .tiff)
        }

        guard !item.types.isEmpty else {
            return false
        }

        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }
}
