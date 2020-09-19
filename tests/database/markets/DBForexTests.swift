import IG
import Combine
import Conbini
import Decimals
import XCTest

final class DBForexTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Test the "successful" retrieval of forex markets from the database.
    func testForexRetrieval() throws {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        let database = try Database(location: .memory)
        
        let epics = ((1...5).map { _ in Market.Epic.forex.randomElement()! })
            .uniqueElements
            .sorted()
        
        do { // Tests database writes of forex markets.
            let apiForex = api.markets.get(epics: .init(epics))
                .expectsOne(timeout: 2, on: self)
            XCTAssertEqual(epics, apiForex.map { $0.instrument.epic }.sorted() )
            
            database.markets.update(apiForex)
                .expectsCompletion(timeout: 0.5, on: self)
        }
        
        do { // Tests the retrieve-all call to the database.
            let dbForex = database.markets.forex.getAll()
                .expectsOne(timeout: 0.5, on: self)
                .sorted { $0.epic < $1.epic }
            XCTAssertEqual(epics, dbForex.map { $0.epic })
        }
        
        do { // Test the retrieve-set call to the database.
            let dbForex = database.markets.forex.get(epics: .init(epics), expectsAll: true)
                .expectsOne(timeout: 0.5, on: self)
                .sorted { $0.epic < $1.epic }
            XCTAssertEqual(epics, dbForex.map { $0.epic })
        }
        
        for epic in epics { // Test the retrieve-one call to the database.
            let market = database.markets.forex.get(epic: epic).expectsOne(timeout: 0.5, on: self)
            XCTAssertEqual(market.epic, epic)
        }
    }
    
    /// Test a forex retrieval for a market that it is not there.
    func testForexRetrievalFailure() throws {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        let database = try Database(location: .memory)

        let epics = ((1...5).map { _ in Market.Epic.forex.randomElement()! })
            .sorted { $0 < $1 }
            .uniqueElements
        let apiForex = api.markets.get(epics: .init(epics)).expectsOne(timeout: 2, on: self)
        database.markets.update(apiForex).expectsCompletion(timeout: 0.5, on: self)

        let notIncludedEpic = Market.Epic.forex.first { !epics.contains($0) }!
        database.markets.forex.get(epic: notIncludedEpic).expectsFailure(timeout: 0.5, on: self)
    }

    /// Test the currency retrieval functions.
    func testForexCurrency() throws {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        let database = try Database(location: .memory)
        // Retrieve 50 forex markets from the server and store them in the database.
        let epics = Market.Epic.forex.prefix(50)
        let apiForex = api.markets.get(epics: .init(epics)).expectsOne(timeout: 2, on: self)
        database.markets.update(apiForex).expectsCompletion(timeout: 0.5, on: self)
        // Retrieve all forex markets from the database and find out the one that has the most matches.
        let dbForex = database.markets.forex.getAll()
            .expectsOne(timeout: 0.5, on: self)
            .sorted { $0.epic < $1.epic }
        
        var dict: [Currency.Code:Int] = .init()
        for market in dbForex {
            for currency in [market.currencies.base, market.currencies.counter] {
                dict[currency] = dict[currency].map { $0 + 1 } ?? 1
            }
        }
        let popularMarket = dict.sorted { $0.value > $1.value }.first!


        let results = database.markets.forex.get(currency: popularMarket.key).expectsOne(timeout: 0.5, on: self)
        XCTAssertEqual(popularMarket.value, results.count)
    }
}

// MARK: -

fileprivate extension Array where Element: Equatable {
    /// Removes the duplicate elements while conserving order.
    var uniqueElements: Self {
        return self.reduce(into: Self.init()) { (result, element) in
            guard !result.contains(element) else { return }
            result.append(element)
        }
    }
}
