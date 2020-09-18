@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API Application related endpoints.
final class APIPriceBatchTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Test price data extraction (by number of data points).
    func testLasPricesExtractionByNumber() {
        let cst: String = "<#CST#>"
        let security: String = "<#X-SECURTY-TOKEN#>"
        
        let num = 300
        let api = API()
        let snapshot = api.scrapped.getPriceSnapshot(epic: "CS.D.EURUSD.MINI.IP", resolution: .minute, numDataPoints: num, scrappedCredentials: (cst, security)).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(snapshot.prices.isEmpty)
        XCTAssertEqual(num, snapshot.prices.count)
    }
    
//    /// Test price data extraction (by date).
//    func testLasPricesExtractionByDate() {
//        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: nil, targetQueue: nil)
//
//        let from = Date().lastTuesday
//
//        let cst: String = "<#CST#>"
//        let security: String = "<#X-SECURTY-TOKEN#>"
//
//        let prices = api.scrapped.getPrices(epic: "CS.D.EURUSD.MINI.IP", resolution: .minute, from: from, to: Date(), scalingFactor: <#Decimal#>, scrappedCredentials: (cst, security)).expectsOne(timeout: 2, on: self)
//        XCTAssertFalse(prices.isEmpty)
//    }
}
