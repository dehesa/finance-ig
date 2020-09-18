@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API Application related endpoints.
final class APICalendarTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Test the economic calendar event extraction.
    func testEventsExtraction() {
        let to = Date()
        let from = to.lastTuesday
        
        let cst: String = "<#CST#>"
        let security: String = "<#X-SECURTY-TOKEN#>"
        
        let api = API()
        let events = api.scrapped.getEvents(epic: "CS.D.EURUSD.MINI.IP", from: from, to: to, scrappedCredentials: (cst, security)).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(events.isEmpty)
        XCTAssertLessThan(events[0].date, events.last!.date)
    }
}
