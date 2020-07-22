import XCTest
@testable import IG
import Combine

final class DBMarketTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Test a market API retrieval and a database insertion.
    func testSingleMarketUpdate() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.CFD.IP"
        let apiMarket = api.markets.get(epic: epic).expectsOne(timeout: 1, on: self)
        
        db.markets.update([apiMarket]).expectsCompletion(timeout: 0.5, on: self)
        
        let dbMarkets = db.markets.getAll().expectsOne(timeout: 0.5, on: self)
        XCTAssertEqual(dbMarkets.count, 1)
        XCTAssertFalse(dbMarkets.debugDescription.isEmpty)
        
        let marketType = db.markets.type(epic: epic).expectsOne(timeout: 0.5, on: self)
        XCTAssertNotNil(marketType)
        XCTAssertEqual(marketType!, .currencies(.forex))
        
        let dbMarket = db.markets.forex.get(epic: epic).expectsOne(timeout: 0.5, on: self)
        XCTAssertEqual(apiMarket.instrument.epic, dbMarket.epic)
    }
    
    /// Test simple market API retrieval and database insertion.
    func testMarketUpdate() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        let all = (Test.Epic.forex + Test.Epic.forexMini).sorted(by: { $0 < $1 })
        for epics in all.chunked(into: 50) {
            let apiMarkets = api.markets.get(epics: .init(epics))
                .expectsOne(timeout: 2, on: self)
                .sorted { $0.instrument.epic < $1.instrument.epic }
            XCTAssertEqual(epics.count, apiMarkets.count)
            
            db.markets.update(apiMarkets).expectsCompletion(timeout: 0.5, on: self)
        }
        
        let dbMarkets = db.markets.getAll()
            .expectsOne(timeout: 0.5, on: self)
            .sorted { $0.epic < $1.epic }
        XCTAssertEqual(all.count, dbMarkets.count)

        for (m, d) in zip(all, dbMarkets) {
            XCTAssertEqual(m, d.epic)
        }
    }
}
