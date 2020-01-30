@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API Application related endpoints.
final class APICalendarTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Test the economic calendar event extraction.
    func testEventsExtraction() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: nil, targetQueue: nil)
        
        let to = Date()
        let from = to.lastTuesday
        
        let cst: String = "<#CST#>"
        let security: String = "<#X-SECURTY-TOKEN#>"
        
        let events = api.scrapped.getEvents(epic: "CS.D.EURUSD.MINI.IP", from: from, to: to, scrappedCredentials: (cst, security)).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(events.isEmpty)
        XCTAssertLessThan(events[0].date, events.last!.date)
        
        for event in events {
            print(event)
        }
    }
}
