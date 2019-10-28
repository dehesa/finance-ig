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
        
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents().set {
            $0.timeZone = .current
            ($0.year, $0.month, $0.day) = (2019, 10, 23)
            ($0.hour, $0.minute) = (18, 0)
        }
        let from = calendar.date(from: components)!
        
        let cst: String = "<#CST#>"
        let security: String = "<#X-SECURTY-TOKEN#>"
        
        let prices = api.scrapped.getLastPrices(epic: "CS.D.EURUSD.MINI.IP", resolution: .minute, from: from, scrappedCredentials: (cst, security)).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(prices.isEmpty)
    }
}
