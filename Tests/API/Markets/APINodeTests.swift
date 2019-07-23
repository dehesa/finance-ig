import XCTest
import ReactiveSwift
@testable import IG

final class APINavigationNodeTests: APITestCase {
    /// Tests navigation nodes retrieval.
    func testNavigationNodes() {
        let nodeId: String? = nil
        let nodeGivenName = "Root"
        let endpoints = self.api.nodes.get(identifier: nodeId, name: nodeGivenName, depth: 0).on(value: {
            XCTAssertEqual($0.identifier, nodeId)
            XCTAssertEqual($0.name, nodeGivenName)
            
            guard let subnodes = $0.subnodes,
                  let markets = $0.markets else {
                return XCTFail("Subnodes and markets were not initalized.")
            }
            
            XCTAssertTrue(subnodes.allSatisfy { $0.identifier != nil && $0.name != nil && $0.subnodes == nil && $0.markets == nil })
            XCTAssertTrue(markets.isEmpty)
        })
        
        self.test("Navigation nodes", endpoints, signingProcess: .oauth, timeout: 1)
    }
    
    /// Test the market search capabilities.
    func testMarketTermSearch() {
        let endpoint = self.api.nodes.getMarkets(matching: "EURUSD").on(value: {
            XCTAssertFalse($0.isEmpty)
        })

        self.test("Market term search", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
