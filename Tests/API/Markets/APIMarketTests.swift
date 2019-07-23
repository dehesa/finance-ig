import XCTest
import ReactiveSwift
@testable import IG

final class APIMarketTests: APITestCase {
    /// Tests market search through epic strings.
    func testMarketEpicSearch() {
        let epics = ["CS.D.EURGBP.MINI.IP", "CS.D.EURUSD.MINI.IP", "CO.D.DX.FCS1.IP", "KA.D.VOD.CASH.IP"]
        
        let endpoint = self.api.markets.get(epics: ["CS.D.EURGBP.MINI.IP", "CS.D.EURUSD.MINI.IP", "CO.D.DX.FCS1.IP", "KA.D.VOD.CASH.IP"]).on(value: {
            XCTAssertEqual($0.count, epics.count)
        })
        
        self.test("Market epic search", endpoint, signingProcess: .oauth, timeout: 1)
    }
    
    func testSingleMarketRetrieval() {
        let epic = "CS.D.EURUSD.MINI.IP"
        
        let endpoint = self.api.markets.get(epic: epic).on(value: {
            XCTAssertEqual($0.instrument.epic, epic)
        })
        
        self.test("Market retrieval", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
