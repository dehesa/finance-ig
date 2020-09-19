import IG
import ConbiniForTesting
import XCTest

final class APIMarketTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests market search through epic strings.
    func testMarkets() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let epics: Set<IG.Market.Epic> = ["CS.D.EURGBP.MINI.IP", "CS.D.EURUSD.MINI.IP", "CO.D.DX.FCS1.IP", "KA.D.VOD.CASH.IP"]
        let markets = api.markets.get(epics: epics).expectsOne(timeout: 2, on: self)
        XCTAssertEqual(markets.count, epics.count)
        XCTAssertEqual(epics.sorted {$0 > $1}, markets.map {$0.instrument.epic}.sorted { $0 > $1 })
    }
    
    /// Tests the market retrieval (for big numbers).
    func testMarketsContinuously() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let epics = Set<IG.Market.Epic>(Market.Epic.forex + Market.Epic.forexMini)
        let markets = api.markets.getContinuously(epics: epics)
            .expectsAll(timeout: 5, on: self)
            .flatMap { $0 }
        XCTAssertEqual(epics.count, markets.count)
    }
    
    /// Test the market retrieval for a single market.
    func testMarketRetrieval() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.MINI.IP"
        let market = api.markets.get(epic: epic).expectsOne(timeout: 2, on: self)
        XCTAssertEqual(market.instrument.epic, epic)
    }
}
