import IG
import ConbiniForTesting
import XCTest

final class APISentimentTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the platform's sentiment list call.
    func testSentiments() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let ids = ["EURGBP", "GC", "VOD-UK"].sorted { $0 > $1 }
        let markets = api.markets.getSentiment(from: ids).expectsOne(timeout: 2, on: self)
        XCTAssertEqual(markets.map { $0.marketIdentifier }.sorted { $0 > $1 }, ids)
        
        let market = markets.first!
        XCTAssertGreaterThan(market.longs, 0)
        XCTAssertGreaterThan(market.shorts, 0)
        XCTAssertEqual(market.longs + market.shorts, 100)
    }
    
    /// Tests the platform's sentiment call.
    func testSentiment() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)

        let id = "EURGBP"
        let market = api.markets.getSentiment(from: id).expectsOne(timeout: 2, on: self)
        XCTAssertGreaterThan(market.longs, 0)
        XCTAssertGreaterThan(market.shorts, 0)
        XCTAssertEqual(market.longs + market.shorts, 100)
    }

    func testMarketRelations() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let id = "EURGBP"
        let markets = api.markets.getSentiment(relatedTo: id).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(markets.isEmpty)
        
        let market = markets.first!
        XCTAssertGreaterThan(market.longs, 0)
        XCTAssertGreaterThan(market.shorts, 0)
        XCTAssertEqual(market.longs + market.shorts, 100)
    }
}
