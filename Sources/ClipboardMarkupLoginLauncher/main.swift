import AppKit
import Foundation

private enum LoginLauncher {
    static func run() -> Int32 {
        let mainAppURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL

        guard mainAppURL.pathExtension == "app" else {
            fputs("Unable to resolve Clipboard Markup app bundle.\n", stderr)
            return 1
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--launched-at-login"]
        configuration.activates = false

        let semaphore = DispatchSemaphore(value: 0)
        var launchError: Error?

        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, error in
            launchError = error
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 10) == .timedOut {
            fputs("Timed out launching Clipboard Markup.\n", stderr)
            return 1
        }

        if let launchError {
            fputs("Unable to launch Clipboard Markup: \(launchError.localizedDescription)\n", stderr)
            return 1
        }

        return 0
    }
}

exit(LoginLauncher.run())
