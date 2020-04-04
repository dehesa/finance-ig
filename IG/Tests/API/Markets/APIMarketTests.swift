import IG
import ConbiniForTesting
import XCTest

final class APIMarketTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests market search through epic strings.
    func testMarkets() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: self.acc), targetQueue: nil)
        
        let epics: Set<IG.Market.Epic> = ["CS.D.EURGBP.MINI.IP", "CS.D.EURUSD.MINI.IP", "CO.D.DX.FCS1.IP", "KA.D.VOD.CASH.IP"]
        let markets = api.markets.get(epics: epics)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(markets.count, epics.count)
        XCTAssertEqual(epics.sorted {$0.rawValue > $1.rawValue}, markets.map {$0.instrument.epic}.sorted {$0.rawValue > $1.rawValue})
    }
    
    /// Tests the market retrieval (for big numbers).
    func testMarketsContinuously() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: self.acc), targetQueue: nil)
        
        let epics = Set<IG.Market.Epic>(Test.Epic.forex + Test.Epic.forexMini)
        let markets = api.markets.getContinuously(epics: epics)
            .expectsAll(timeout: 4, on: self)
            .flatMap { $0 }
        XCTAssertEqual(epics.count, markets.count)
    }
    
    /// Test the market retrieval for a single market.
    func testMarketRetrieval() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: self.acc), targetQueue: nil)
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.MINI.IP"
        let market = api.markets.get(epic: epic)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(market.instrument.epic, epic)
    }
}
