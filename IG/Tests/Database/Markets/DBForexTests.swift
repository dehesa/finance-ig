import XCTest
@testable import IG
import Combine

final class DBForexTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Test the "successful" retrieval of forex markets from the database.
    func testForexRetrieval() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        let epics = ((1...5).map { _ in Test.Epic.forex.randomElement()! })
            .sorted { $0 < $1 }
            .uniqueElements
        let apiForex = api.markets.get(epics: .init(epics)).expectsOne(timeout: 2, on: self)
        db.markets.update(apiForex).expectsCompletion(timeout: 0.5, on: self)
        
        let dbForex = db.markets.forex.getAll()
            .expectsOne(timeout: 0.5, on: self)
            .sorted { $0.epic < $1.epic }
        XCTAssertEqual(epics, dbForex.map { $0.epic })
        
        for epic in epics {
            let market = db.markets.forex.get(epic: epic).expectsOne(timeout: 0.5, on: self)
            XCTAssertEqual(market.epic, epic)
        }
    }
    
    /// Test a forex retrieval for a market that it is not there.
    func testForexRetrievalFailure() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)

        let epics = ((1...5).map { _ in Test.Epic.forex.randomElement()! })
            .sorted { $0 < $1 }
            .uniqueElements
        let apiForex = api.markets.get(epics: .init(epics)).expectsOne(timeout: 2, on: self)
        db.markets.update(apiForex).expectsCompletion(timeout: 0.5, on: self)

        let notIncludedEpic = Test.Epic.forex.first { !epics.contains($0) }!
        db.markets.forex.get(epic: notIncludedEpic).expectsFailure(timeout: 0.5, on: self)
    }

    /// Test the currency retrieval functions.
    func testForexCurrency() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        // Retrieve 50 forex markets from the server and store them in the database.
        let epics = Test.Epic.forex.prefix(50)
        let apiForex = api.markets.get(epics: .init(epics)).expectsOne(timeout: 2, on: self)
        db.markets.update(apiForex).expectsCompletion(timeout: 0.5, on: self)
        // Retrieve all forex markets from the database and find out the one that has the most matches.
        let dbForex = db.markets.forex.getAll()
            .expectsOne(timeout: 0.5, on: self)
            .sorted { $0.epic < $1.epic }
        
        var dict: [IG.Currency.Code:Int] = .init()
        for market in dbForex {
            for currency in [market.currencies.base, market.currencies.counter] {
                dict[currency] = dict[currency].map { $0 + 1 } ?? 1
            }
        }
        let popularMarket = dict.sorted { $0.value > $1.value }.first!


        let results = db.markets.forex.get(currency: popularMarket.key).expectsOne(timeout: 0.5, on: self)
        XCTAssertEqual(popularMarket.value, results.count)
    }
}
