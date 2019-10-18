import IG
import XCTest

final class APIMarketTests: XCTestCase {
    /// Tests market search through epic strings.
    func testMarkets() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let epics: Set<IG.Market.Epic> = ["CS.D.EURGBP.MINI.IP", "CS.D.EURUSD.MINI.IP", "CO.D.DX.FCS1.IP", "KA.D.VOD.CASH.IP"]
        let markets = api.markets.get(epics: epics)
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(markets.count, epics.count)
        XCTAssertEqual(epics.sorted {$0.rawValue > $1.rawValue}, markets.map {$0.instrument.epic}.sorted {$0.rawValue > $1.rawValue})
    }
    
    /// Tests the market retrieval (for big numbers).
    func testMarketsContinuously() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let epics = Set<IG.Market.Epic>(Test.Epic.forex + Test.Epic.forexMini)
        let markets = api.markets.getContinuously(epics: epics)
            .expectsAll { self.wait(for: [$0], timeout: 4) }
            .flatMap { $0 }
        XCTAssertEqual(epics.count, markets.count)
    }
    
    /// Test the market retrieval for a single market.
    func testMarketRetrieval() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.MINI.IP"
        let market = api.markets.get(epic: epic)
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(market.instrument.epic, epic)
    }
}
