@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API history activity related enpoints
final class APIPriceTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests paginated activity retrieval.
    func testPrices() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        
        let fromDate = Date().lastTuesday
        let toDate = Calendar(identifier: .iso8601).date(byAdding: .hour, value: 1, to: fromDate)!
        
        let events = api.price.get(epic: "CS.D.EURUSD.MINI.IP", from: fromDate, to: toDate, resolution: .minute10).expectsAll(timeout: 2, on: self)
        XCTAssertFalse(events.isEmpty)
        
        let prices = events.flatMap { $0.prices }
        let allowance = events.map { $0.allowance }
        XCTAssertFalse(prices.isEmpty)
        XCTAssertFalse(allowance.isEmpty)
            
        let element = prices[Int.random(in: 0..<prices.count)]
        XCTAssertGreaterThanOrEqual(element.date, fromDate)
        XCTAssertLessThanOrEqual(element.date, toDate)
    }
}
