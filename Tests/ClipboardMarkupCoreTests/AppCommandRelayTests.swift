@testable import ClipboardMarkupCore
import XCTest

@MainActor
final class AppCommandRelayTests: XCTestCase {
    func testSearchRequestsAreConsumedOnce() {
        let relay = AppCommandRelay()

        XCTAssertFalse(relay.consumeSearchRequestIfNeeded())

        relay.showSearch()

        XCTAssertEqual(relay.searchRequestID, 1)
        XCTAssertTrue(relay.consumeSearchRequestIfNeeded())
        XCTAssertFalse(relay.consumeSearchRequestIfNeeded())
    }

    func testMarkupRequestsAreConsumedOnce() {
        let relay = AppCommandRelay()

        XCTAssertFalse(relay.consumeMarkupRequestIfNeeded())

        relay.markupSelectedClip()

        XCTAssertEqual(relay.markupRequestID, 1)
        XCTAssertTrue(relay.consumeMarkupRequestIfNeeded())
        XCTAssertFalse(relay.consumeMarkupRequestIfNeeded())
    }
}
