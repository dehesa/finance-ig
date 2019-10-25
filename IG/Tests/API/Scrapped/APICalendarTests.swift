@testable import IG
import XCTest

/// Tests API Application related endpoints.
final class APICalendarTests: XCTestCase {
    /// Test the economic calendar event extraction.
    func testEventsExtraction() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents().set {
            $0.timeZone = .current
            ($0.year, $0.month, $0.day) = (2019, 7, 1)
            ($0.hour, $0.minute) = (0, 0)
        }
        let from = calendar.date(from: components)!
        let to = calendar.date(from: components.set { $0.month = 11 })!
        
        let cst: String = "<#Fill me#>"
        let security: String = "<#Fill me#>"
        
        let events = api.scrapped.events(epic: "CS.D.EURUSD.MINI.IP", from: from, to: to, scrappedCredentials: (cst, security)).expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertFalse(events.isEmpty)
        XCTAssertLessThan(events[0].date, events.last!.date)
    }
}
