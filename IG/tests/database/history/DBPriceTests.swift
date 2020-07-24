@testable import IG
import Combine
import XCTest

final class DBPriceTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Test the retrieval of price data from a table that it is not there.
    func testNonExistentPriceTable() {
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        let from = Date().lastTuesday
        let to = Calendar(identifier: .iso8601).date(byAdding: .hour, value: 1, to: from)!
        let prices = db.prices.get(epic: Test.Epic.forex.randomElement()!, from: from, to: to).expectsOne(timeout: 0.5, on: self)
        XCTAssertTrue(prices.isEmpty)
    }

    /// Tests the creation of a price table.
    func testPriceTableCreation() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        let from = Date().lastTuesday
        let to = Calendar(identifier: .iso8601).date(byAdding: .hour, value: 1, to: from)!
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.CFD.IP"
        let apiMarket = api.markets.get(epic: epic).expectsOne(timeout: 2, on: self)
        db.markets.update(apiMarket).expectsCompletion(timeout: 0.5, on: self)
        XCTAssertTrue(db.prices.get(epic: epic, from: from, to: to).expectsOne(timeout: 0.5, on: self).isEmpty)
        
        let apiPrices = api.prices.getContinuously(epic: epic, from: from, to: to)
            .map { (prices, _) -> [API.Price] in prices }
            .expectsAll(timeout: 4, on: self)
            .flatMap { $0 }
        XCTAssertTrue(apiPrices.isSorted { $0.date < $1.date })
        db.prices.update(apiPrices, epic: epic).expectsCompletion(timeout: 0.5, on: self)
        
        let dbPrices = db.prices.get(epic: epic, from: from, to: to).expectsOne(timeout: 0.5, on: self)
        XCTAssertTrue(dbPrices.isSorted { $0.date < $1.date })
        XCTAssertEqual(apiPrices.count, dbPrices.count)
        
        for (apiPrice, dbPrice) in zip(apiPrices, dbPrices) {
            XCTAssertEqual(apiPrice.date, dbPrice.date)
            XCTAssertEqual(apiPrice.open.bid, dbPrice.open.bid)
            XCTAssertEqual(apiPrice.open.ask, dbPrice.open.ask)
            XCTAssertEqual(apiPrice.close.bid, dbPrice.close.bid)
            XCTAssertEqual(apiPrice.close.ask, dbPrice.close.ask)
            XCTAssertEqual(apiPrice.lowest.bid, dbPrice.lowest.bid)
            XCTAssertEqual(apiPrice.lowest.ask, dbPrice.lowest.ask)
            XCTAssertEqual(apiPrice.highest.bid, dbPrice.highest.bid)
            XCTAssertEqual(apiPrice.highest.ask, dbPrice.highest.ask)
            XCTAssertEqual(Int(apiPrice.volume!), dbPrice.volume)
        }
    }
}
