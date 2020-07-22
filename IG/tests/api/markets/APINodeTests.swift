import IG
import ConbiniForTesting
import XCTest

final class APINavigationNodeTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests navigation nodes retrieval.
    func testNavigationRootNodes() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        
        let rootNode = api.nodes.get(identifier: nil, name: "Root", depth: .none).expectsOne(timeout: 2, on: self)
        XCTAssertNil(rootNode.id)
        XCTAssertEqual(rootNode.name, "Root")
        
        XCTAssertFalse(rootNode.subnodes!.isEmpty)
        XCTAssertTrue(rootNode.subnodes!.allSatisfy { $0.id != nil && $0.name != nil && $0.subnodes == nil && $0.markets == nil })
        XCTAssertTrue(rootNode.markets!.isEmpty)
//        XCTAssertFalse(rootNode.debugDescription.isEmpty)
    }
    
    // Tests the major forex node.
    func testNavigationMarketsSubtree() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        
        let target: (identifier: String, name: String) = ("264134", "Major FX")
        let node = api.nodes.get(identifier: target.identifier, name: target.name, depth: .none).expectsOne(timeout: 2, on: self)
        XCTAssertEqual(node.id, target.identifier)
        XCTAssertEqual(node.name, target.name)
        XCTAssertNotNil(node.subnodes)
        XCTAssertTrue(node.subnodes!.isEmpty)
        XCTAssertNotNil(node.markets)
        XCTAssertFalse(node.markets!.isEmpty)
    }
    
    /// Drill down two levels in the navigation nodes tree.
    func testNavigationSubtree() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        
        let target: (identifier: String, name: String) = ("195235", "FX")
        let node = api.nodes.get(identifier: target.identifier, name: target.name, depth: .all).expectsOne(timeout: 8, on: self)
        XCTAssertEqual(node.id, target.identifier)
        XCTAssertEqual(node.name, target.name)
        XCTAssertNotNil(node.subnodes)
        XCTAssertFalse(node.subnodes!.isEmpty)
        XCTAssertNotNil(node.markets)
    }

    /// Test the market search capabilities.
    func testMarketTermSearch() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)

        let markets = api.nodes.getMarkets(matching: "NZD").expectsOne(timeout: 2, on: self)
        XCTAssertFalse(markets.isEmpty)
        
        let now = Date()
        for market in markets {
            XCTAssertLessThanOrEqual(market.snapshot.date, now)
        }
    }
}
