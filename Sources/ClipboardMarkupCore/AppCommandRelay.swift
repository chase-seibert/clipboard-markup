import AppKit
import Combine

@MainActor
public final class AppCommandRelay: ObservableObject {
    public var showWindowHandler: (() -> Void)?

    public init() {}

    public func showMainWindow() {
        showWindowHandler?()
    }
}
