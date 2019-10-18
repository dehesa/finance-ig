import XCTest
@testable import IG
import Combine

final class DBPriceTests: XCTestCase {
    /// Test the retrieval of price data from a table that it is not there.
    func testNonExistentPriceTable() {
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        let prices = db.history.getPrices(epic: Test.Epic.forex.randomElement()!, from: twoHoursAgo).expectsOne { self.wait(for: [$0], timeout: 0.5) }
        XCTAssertTrue(prices.isEmpty)
    }

    /// Tests the creation of a price table.
    func testPriceTableCreation() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.CFD.IP"
        let apiMarket = api.markets.get(epic: epic).expectsOne { self.wait(for: [$0], timeout: 0.5) }
        db.markets.update(apiMarket).expectsCompletion { self.wait(for: [$0], timeout: 0.5) }
        XCTAssertTrue(db.history.getPrices(epic: epic, from: twoHoursAgo).expectsOne { self.wait(for: [$0], timeout: 0.5) }.isEmpty)
        
        let apiPrices = api.history.getPricesContinuously(epic: epic, from: twoHoursAgo)
            .map { (prices, _) -> [IG.API.Price] in prices }
            .expectsAll { self.wait(for: [$0], timeout: 4) }
            .flatMap { $0 }
        XCTAssertTrue(apiPrices.isSorted { $0.date < $1.date })
        
        db.history.update(prices: apiPrices, epic: epic).expectsCompletion { self.wait(for: [$0], timeout: 0.5) }
        let dbPrices = db.history.getPrices(epic: epic, from: twoHoursAgo).expectsOne { self.wait(for: [$0], timeout: 0.5) }
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

extension DBPriceTests {
    var twoHoursAgo: Date {
        Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
    }
}
