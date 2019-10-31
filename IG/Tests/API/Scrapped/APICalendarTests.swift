@testable import IG
import XCTest

/// Tests API Application related endpoints.
final class APICalendarTests: XCTestCase {
    /// Test the economic calendar event extraction.
    func testEventsExtraction() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: nil, targetQueue: nil)
        
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
