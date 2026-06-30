import AppKit

enum ClipboardCapture {
    case text(plainText: String, richRTF: Data?, fingerprint: String)
    case image(NSImage, fingerprint: String)

    var fingerprint: String {
        switch self {
        case let .text(_, _, fingerprint):
            fingerprint
        case let .image(_, fingerprint):
            fingerprint
        }
    }
}
