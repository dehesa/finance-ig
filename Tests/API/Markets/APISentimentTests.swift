import XCTest
import ReactiveSwift
@testable import IG

final class APISentimentTests: APITestCase {
    /// Tests the platform's sentiment list call.
    func testSentiments() {
        let marketIdentifiers = ["EURGBP", "GC", "VOD-UK"]
        
        let endpoint = self.api.markets.getSentiment(from: marketIdentifiers).on(value: { (markets) in
            guard let market = markets.first else {
                return XCTFail("There are no market sentiments.")
            }
            
            XCTAssertGreaterThan(market.longs, 0)
            XCTAssertGreaterThan(market.shorts, 0)
            XCTAssertEqual(market.longs + market.shorts, 100)
        })
        
        self.test("Sentiment retrieval", endpoint, signingProcess: .oauth, timeout: 1)
    }
    
    /// Tests the platform's sentiment call.
    func testSentiment() {
        let marketIdentifier = "EURGBP"
        
        let endpoint = self.api.markets.getSentiment(from: marketIdentifier).on(value: { (market) in
            XCTAssertGreaterThan(market.longs, 0)
            XCTAssertGreaterThan(market.shorts, 0)
            XCTAssertEqual(market.longs + market.shorts, 100)
        })
        
        self.test("Sentiment retrieval", endpoint, signingProcess: .oauth, timeout: 1)
    }
    
    func testMarketRelations() {
        let marketIdentifier = "EURGBP"
        
        let endpoint = self.api.markets.getRelated(to: marketIdentifier).on(value: { (markets) in
            guard let market = markets.first else {
                return XCTFail("There are no market sentiments.")
            }
            
            XCTAssertGreaterThan(market.longs, 0)
            XCTAssertGreaterThan(market.shorts, 0)
            XCTAssertEqual(market.longs + market.shorts, 100)
        })
        
        self.test("Sentiment retrieval", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
