import AppKit
import Combine

@MainActor
public final class AppCommandRelay: ObservableObject {
    @Published public private(set) var searchRequestID = 0

    public var showWindowHandler: (() -> Void)?
    private var handledSearchRequestID = 0

    public init() {}

    public func showMainWindow() {
        showWindowHandler?()
    }

    public func showSearch() {
        showMainWindow()
        searchRequestID += 1
    }

    public func consumeSearchRequestIfNeeded() -> Bool {
        guard searchRequestID > handledSearchRequestID else {
            return false
        }

        handledSearchRequestID = searchRequestID
        return true
    }
}
