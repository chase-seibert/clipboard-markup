import AppKit
import SwiftUI

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex) ?? .systemRed)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6, let integer = Int(value, radix: 16) else {
            return nil
        }

        let red = CGFloat((integer >> 16) & 0xFF) / 255
        let green = CGFloat((integer >> 8) & 0xFF) / 255
        let blue = CGFloat(integer & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
