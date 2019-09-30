@testable import IG
import ReactiveSwift
import XCTest

class DBForexTests: XCTestCase {
    /// Test the "successful" retrieval of forex markets from the database.
    func testForexRetrieval() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api, targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        let epics = ((1...5).map { (_) in Test.Epic.forex.randomElement()! }).sorted { $0 < $1 }
        let apiForex = try! api.markets.get(epics: .init(epics)).single()!.get()
        try! db.markets.update(apiForex).single()!.get()
        
        let dbForex = (try! db.markets.forex.getAll().single()!.get()).sorted { $0.epic < $1.epic }
        XCTAssertEqual(epics, dbForex.map { $0.epic })
        
        for epic in epics {
            let market = try! db.markets.forex.get(epic: epic).single()!.get()
            XCTAssertEqual(market.epic, epic)
        }
    }
    
    /// Test a forex retrieval for a market that it is not there.
    func testForexRetrievalFailure() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api, targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        let epics = ((1...5).map { (_) in Test.Epic.forex.randomElement()! }).sorted { $0 < $1 }
        let apiForex = try! api.markets.get(epics: .init(epics)).single()!.get()
        try! db.markets.update(apiForex).single()!.get()
        
        let notIncludedEpic = Test.Epic.forex.first { !epics.contains($0) }!
        switch db.markets.forex.get(epic: notIncludedEpic).single()! {
        case .success(let forex): return XCTFail(#"The market with epic "\#(forex.epic.rawValue)" was matched for epic: "\#(notIncludedEpic.rawValue)""#)
        case .failure(let error): XCTAssertEqual(error.type, .invalidResponse, "An empty response was expected, but another error type was returned")
        }
    }
    
    /// Test the currency retrieval functions.
    func testForexCurrency() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api, targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        // Retrieve 50 forex markets from the server and store them in the database.
        let epics = Test.Epic.forex.prefix(50)
        let apiForex = try! api.markets.get(epics: .init(epics)).single()!.get()
        try! db.markets.update(apiForex).single()!.get()
        // Retrieve all forex markets from the database and find out the one that has the most matches.
        let dbForex = (try! db.markets.forex.getAll().single()!.get()).sorted { $0.epic < $1.epic }
        var dict: [IG.Currency.Code:Int] = .init()
        for market in dbForex {
            for currency in [market.currencies.base, market.currencies.counter] {
                dict[currency] = dict[currency].map { $0 + 1 } ?? 1
            }
        }
        let popularMarket = dict.sorted { $0.value > $1.value }.first!

        
        let results = try! db.markets.forex.get(currency: popularMarket.key).single()!.get()
        XCTAssertEqual(popularMarket.value, results.count)
    }
}
