@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API Application related endpoints.
final class APIPriceBatchTests: XCTestCase {
    /// Test price data extraction (by number of data points).
    func testLasPricesExtractionByNumber() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: nil, targetQueue: nil)
        
        let cst: String = "<#CST#>"
        let security: String = "<#X-SECURTY-TOKEN#>"
        
        let num = 300
        let prices = api.scrapped.getLastPrices(epic: "CS.D.EURUSD.MINI.IP", resolution: .minute, numDataPoints: num, scrappedCredentials: (cst, security)).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(prices.isEmpty)
        XCTAssertEqual(num, prices.count)
    }
    
    /// Test price data extraction (by date).
    func testLasPricesExtractionByDate() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: nil, targetQueue: nil)
        
        let from = Date().lastTuesday
        
        let cst: String = "<#CST#>"
        let security: String = "<#X-SECURTY-TOKEN#>"
        
        let prices = api.scrapped.getLastPrices(epic: "CS.D.EURUSD.MINI.IP", resolution: .minute, from: from, scrappedCredentials: (cst, security)).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(prices.isEmpty)
    }
}
