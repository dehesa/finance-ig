import IG
import Combine
import ConbiniForTesting
import XCTest

final class DBPriceTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Test the retrieval of price data from a table that it is not there.
    func testNonExistentPriceTable() throws {
        let database = try Database(location: .memory)
        
        let from = Date().lastTuesday
        let to = Calendar(identifier: .iso8601).date(byAdding: .hour, value: 1, to: from)!
        let prices = database.prices.get(epic: Market.Epic.forex.randomElement()!, from: from, to: to).expectsOne(timeout: 0.5, on: self)
        XCTAssertTrue(prices.isEmpty)
    }

    /// Tests the creation of a price table.
    func testPriceTableCreation() throws {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        let database = try Database(location: .memory)
        
        let from = Date().lastTuesday
        let to = Calendar(identifier: .iso8601).date(byAdding: .hour, value: 1, to: from)!
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.CFD.IP"
        let apiMarket = api.markets.get(epic: epic).expectsOne(timeout: 2, on: self)
        database.markets.update(apiMarket).expectsCompletion(timeout: 0.5, on: self)
        XCTAssertTrue(database.prices.get(epic: epic, from: from, to: to).expectsOne(timeout: 0.5, on: self).isEmpty)
        
        let apiPrices = api.prices.getContinuously(epic: epic, from: from, to: to)
            .map { (prices, _) -> [API.Price] in prices }
            .expectsAll(timeout: 4, on: self)
            .flatMap { $0 }
        XCTAssertTrue(apiPrices.isSorted { $0.date < $1.date })
        database.prices.update(apiPrices, epic: epic).expectsCompletion(timeout: 0.5, on: self)
        
        let dbPrices = database.prices.get(epic: epic, from: from, to: to).expectsOne(timeout: 0.5, on: self)
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

// MARK: -

fileprivate extension Array {
    /// Checks whether the receiving array is sorted following the given predicate.
    /// - parameter areInIncreasingOrder: A predicate that returns `true` if its first argument should be ordered before its second argument; otherwise, `false`.
    func isSorted(_ areInIncreasingOrder: (Element,Element) throws ->Bool) rethrows -> Bool {
        var indeces: (previous: Index, current: Index) = (self.startIndex, self.startIndex.advanced(by: 1))

        while indeces.current != self.endIndex {
            guard try areInIncreasingOrder(self[indeces.previous], self[indeces.current]) else { return false }
            indeces = (indeces.current, indeces.current.advanced(by: 1))
        }

        return true
    }
}
