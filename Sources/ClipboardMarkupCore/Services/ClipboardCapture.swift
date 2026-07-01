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

    var analyticsKind: AnalyticsClipCaptureKind {
        switch self {
        case let .text(_, richRTF, _):
            richRTF == nil ? .text : .richText
        case .image:
            .image
        }
    }
}
