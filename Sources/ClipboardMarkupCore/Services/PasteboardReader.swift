import AppKit

enum PasteboardReader {
    static func capture(from pasteboard: NSPasteboard = .general) -> ClipboardCapture? {
        if let image = readImage(from: pasteboard),
           let pngData = image.pngData {
            return .image(image, fingerprint: Fingerprint.make(prefix: "image", data: pngData))
        }

        if let richText = readRichText(from: pasteboard) {
            let fingerprintData = richText.richRTF ?? Data(richText.plainText.utf8)
            return .text(
                plainText: richText.plainText,
                richRTF: richText.richRTF,
                fingerprint: Fingerprint.make(prefix: "text", data: fingerprintData)
            )
        }

        guard let string = pasteboard.string(forType: .string),
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return .text(
            plainText: string,
            richRTF: nil,
            fingerprint: Fingerprint.make(prefix: "text", string: string)
        )
    }

    private static func readImage(from pasteboard: NSPasteboard) -> NSImage? {
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            return image
        }

        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] {
            for url in urls {
                let fileURL = url as URL
                guard let image = NSImage(contentsOf: fileURL) else {
                    continue
                }
                return image
            }
        }

        return nil
    }

    private static func readRichText(from pasteboard: NSPasteboard) -> (plainText: String, richRTF: Data?)? {
        if let rtf = pasteboard.data(forType: .rtf),
           let attributed = try? NSAttributedString(
            data: rtf,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            let plainText = attributed.string
            guard !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return (plainText, rtf)
        }

        if let rtfd = pasteboard.data(forType: .rtfd),
           let attributed = try? NSAttributedString(
            data: rtfd,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
           ) {
            let plainText = attributed.string
            guard !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            let range = NSRange(location: 0, length: attributed.length)
            let rtf = try? attributed.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            return (plainText, rtf)
        }

        return nil
    }
}
