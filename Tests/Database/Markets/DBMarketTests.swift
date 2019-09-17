@testable import IG
import ReactiveSwift
import XCTest

final class DBMarketTests: XCTestCase {
    /// Test simple market API retrieval and database insertion.
    func testMarketUpdate() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api, targetQueue: nil)
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        let all = (Test.Epic.forex + Test.Epic.forexMini).sorted(by: { $0.rawValue < $1.rawValue })
        for epics in all.chunked(into: 50) {
            let apiMarkets = (try! api.markets.get(epics: .init(epics)).single()!.get()).sorted { $0.instrument.epic < $1.instrument.epic }
            XCTAssertEqual(epics.count, apiMarkets.count)
            
            try! db.markets.update(apiMarkets).single()!.get()
        }
        
        let dbMarkets = (try! db.markets.getAll().single()!.get()).sorted { $0.epic < $1.epic }
        XCTAssertEqual(all.count, dbMarkets.count)
        
        for (m, d) in zip(all, dbMarkets) {
            XCTAssertEqual(m, d.epic)
        }
    }
}
