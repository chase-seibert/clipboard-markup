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
}
