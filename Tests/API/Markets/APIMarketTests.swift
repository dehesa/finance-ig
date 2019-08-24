@testable import IG
import ReactiveSwift
import XCTest

final class APIMarketTests: XCTestCase {
    /// Tests market search through epic strings.
    func testMarkets() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let epics: Set<IG.Market.Epic> = ["CS.D.EURGBP.MINI.IP", "CS.D.EURUSD.MINI.IP", "CO.D.DX.FCS1.IP", "KA.D.VOD.CASH.IP"]
        let markets = try! api.markets.get(epics: epics).single()!.get()
        XCTAssertEqual(markets.count, epics.count)
        XCTAssertEqual(epics.sorted {$0.rawValue > $1.rawValue}, markets.map {$0.instrument.epic}.sorted {$0.rawValue > $1.rawValue})
    }
    
    func testMarketRetrieval() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.MINI.IP"
        let market = try! api.markets.get(epic: epic).single()!.get()
        XCTAssertEqual(market.instrument.epic, epic)
    }
}
