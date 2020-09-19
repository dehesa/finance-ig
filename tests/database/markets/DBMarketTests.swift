import IG
import Combine
import XCTest

final class DBMarketTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Test a market API retrieval and a database insertion.
    func testSingleMarketUpdate() throws {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        let database = try Database(location: .memory)
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.CFD.IP"
        let apiMarket = api.markets.get(epic: epic).expectsOne(timeout: 1, on: self)
        
        database.markets.update([apiMarket]).expectsCompletion(timeout: 0.5, on: self)
        
        let dbMarkets = database.markets.getAll().expectsOne(timeout: 0.5, on: self)
        XCTAssertEqual(dbMarkets.count, 1)
        XCTAssertFalse(dbMarkets.debugDescription.isEmpty)
        
        let marketType = database.markets.type(epic: epic).expectsOne(timeout: 0.5, on: self)
        XCTAssertNotNil(marketType)
        XCTAssertEqual(marketType!, .currencies(.forex))
        
        let dbMarket = database.markets.forex.get(epic: epic).expectsOne(timeout: 0.5, on: self)
        XCTAssertEqual(apiMarket.instrument.epic, dbMarket.epic)
    }
    
    /// Test simple market API retrieval and database insertion.
    func testMarketUpdate() throws {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        let database = try Database(location: .memory)
        
        let all = (Market.Epic.forex + Market.Epic.forexMini).sorted(by: { $0 < $1 })
        for epics in all.chunked(into: 50) {
            let apiMarkets = api.markets.get(epics: .init(epics))
                .expectsOne(timeout: 2, on: self)
                .sorted { $0.instrument.epic < $1.instrument.epic }
            XCTAssertEqual(epics.count, apiMarkets.count)
            
            database.markets.update(apiMarkets).expectsCompletion(timeout: 0.5, on: self)
        }
        
        let dbMarkets = database.markets.getAll()
            .expectsOne(timeout: 0.5, on: self)
            .sorted { $0.epic < $1.epic }
        XCTAssertEqual(all.count, dbMarkets.count)

        for (m, d) in zip(all, dbMarkets) {
            XCTAssertEqual(m, d.epic)
        }
    }
}
