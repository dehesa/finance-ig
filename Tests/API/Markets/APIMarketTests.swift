import XCTest
import Utils
import ReactiveSwift
@testable import IG

final class APIMarketTests: APITestCase {
    /// Tests market search through epic strings.
    func testMarketEpicSearch() {
        let endpoint = self.api.markets(epics: ["CS.D.EURUSD.MINI.IP", "CO.D.DX.FCS1.IP"]).on(value: {
            XCTAssertEqual($0.count, 2)
        })
        
        self.test("Market epic search", endpoint, signingProcess: .oauth, timeout: 1)
    }
    
    func testSingleMarketRetrieval() {
        let epic = "CS.D.EURUSD.MINI.IP"
        let endpoint = self.api.market(epic: epic).on(value: {
            XCTAssertEqual($0.instrument.epic, epic)
        })
        
        self.test("Market retrieval", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
