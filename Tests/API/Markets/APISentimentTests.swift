@testable import IG
import ReactiveSwift
import XCTest

final class APISentimentTests: XCTestCase {
    /// Tests the platform's sentiment list call.
    func testSentiments() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let ids = ["EURGBP", "GC", "VOD-UK"].sorted { $0 > $1 }
        let markets = try! api.markets.getSentiment(from: ids).single()!.get()
        XCTAssertEqual(markets.map { $0.marketIdentifier }.sorted { $0 > $1 }, ids)
        
        let market = markets.first!
        XCTAssertGreaterThan(market.longs, 0)
        XCTAssertGreaterThan(market.shorts, 0)
        XCTAssertEqual(market.longs + market.shorts, 100)
    }
    
    /// Tests the platform's sentiment call.
    func testSentiment() {
        let api = Test.makeAPI(credentials: Test.credentials.api)

        let id = "EURGBP"
        let market = try! api.markets.getSentiment(from: id).single()!.get()
        XCTAssertGreaterThan(market.longs, 0)
        XCTAssertGreaterThan(market.shorts, 0)
        XCTAssertEqual(market.longs + market.shorts, 100)
    }

    func testMarketRelations() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let id = "EURGBP"
        let markets = try! api.markets.getSentimentRelated(to: id).single()!.get()
        XCTAssertFalse(markets.isEmpty)
        
        let market = markets.first!
        XCTAssertGreaterThan(market.longs, 0)
        XCTAssertGreaterThan(market.shorts, 0)
        XCTAssertEqual(market.longs + market.shorts, 100)
    }
}
