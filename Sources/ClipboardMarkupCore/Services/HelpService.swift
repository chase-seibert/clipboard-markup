import AppKit
import Foundation

public enum HelpService {
    public static func openHelp() {
        guard let url = Bundle.module.url(
            forResource: "ClipboardMarkupHelp",
            withExtension: "html",
            subdirectory: "Help"
        ) else {
            NSSound.beep()
            return
        }

        NSWorkspace.shared.open(url)
    }
}
