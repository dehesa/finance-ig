import XCTest
import ReactiveSwift
@testable import IG

final class APINavigationNodeTests: APITestCase {
    /// Tests navigation nodes retrieval.
    func testNavigationNodes() {
        let endpoints = self.api.navigationNodes().on(value: {
            XCTAssertTrue($0.markets.isEmpty)
            XCTAssertTrue($0.nodes.allSatisfy { !$0.identifier.isEmpty && !$0.name.isEmpty })
            XCTAssertNotNil($0.nodes.first { $0.name == "Cryptocurrency" })
        }).call(on: self.api) { (api, _) in
            self.api.navigationNodes(underNode: "409138")
        }.on(value: {
            XCTAssertTrue($0.nodes.isEmpty)
            XCTAssertNotNil($0.markets.first)
        })
        
        self.test("Navigation nodes", endpoints, signingProcess: .oauth, timeout: 2)
    }
    
    /// Test the market search capabilities.
    func testMarketTermSearch() {
        let endpoint = self.api.markets(searchTerm: "EUR").on(value: {
            XCTAssertFalse($0.isEmpty)
        })
        
        self.test("Market term search", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
