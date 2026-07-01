import AppKit
import Combine

@MainActor
public final class AppCommandRelay: ObservableObject {
    @Published public private(set) var searchRequestID = 0
    @Published public private(set) var renameRequestID = 0
    @Published public private(set) var markupRequestID = 0

    public var showWindowHandler: (() -> Void)?
    private var handledSearchRequestID = 0
    private var handledMarkupRequestID = 0

    public init() {}

    public func showMainWindow() {
        showWindowHandler?()
    }

    public func showSearch() {
        showMainWindow()
        searchRequestID += 1
    }

    public func renameSelectedClip() {
        showMainWindow()
        renameRequestID += 1
    }

    public func markupSelectedClip() {
        showMainWindow()
        markupRequestID += 1
    }

    public func consumeSearchRequestIfNeeded() -> Bool {
        guard searchRequestID > handledSearchRequestID else {
            return false
        }

        handledSearchRequestID = searchRequestID
        return true
    }

    public func consumeMarkupRequestIfNeeded() -> Bool {
        guard markupRequestID > handledMarkupRequestID else {
            return false
        }

        handledMarkupRequestID = markupRequestID
        return true
    }
}
