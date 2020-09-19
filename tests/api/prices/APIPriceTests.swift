import IG
import ConbiniForTesting
import XCTest

/// Tests API history activity related enpoints
final class APIPriceTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests paginated activity retrieval.
    func testPrices() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let fromDate = Date().lastTuesday
        let toDate = Calendar(identifier: .iso8601).date(byAdding: .hour, value: 1, to: fromDate)!
        
        let events = api.prices.get(epic: "CS.D.EURUSD.MINI.IP", from: fromDate, to: toDate, resolution: .minute10).expectsAll(timeout: 2, on: self)
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
