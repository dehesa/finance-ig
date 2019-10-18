import IG
import XCTest

final class APINavigationNodeTests: XCTestCase {
    /// Tests navigation nodes retrieval.
    func testNavigationRootNodes() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let rootNode = api.nodes.get(identifier: nil, name: "Root", depth: .none)
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertNil(rootNode.identifier)
        XCTAssertEqual(rootNode.name, "Root")
        
        XCTAssertFalse(rootNode.subnodes!.isEmpty)
        XCTAssertTrue(rootNode.subnodes!.allSatisfy { $0.identifier != nil && $0.name != nil && $0.subnodes == nil && $0.markets == nil })
        XCTAssertTrue(rootNode.markets!.isEmpty)
        XCTAssertFalse(rootNode.debugDescription.isEmpty)
    }
    
    // Tests the major forex node.
    func testNavigationMarketsSubtree() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let target: (identifier: String, name: String) = ("264134", "Major FX")
        let node = api.nodes.get(identifier: target.identifier, name: target.name, depth: .none)
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(node.identifier, target.identifier)
        XCTAssertEqual(node.name, target.name)
        XCTAssertNotNil(node.subnodes)
        XCTAssertTrue(node.subnodes!.isEmpty)
        XCTAssertNotNil(node.markets)
        XCTAssertFalse(node.markets!.isEmpty)
    }
    
    /// Drill down two levels in the navigation nodes tree.
    func testNavigationSubtree() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let target: (identifier: String, name: String) = ("195235", "FX")
        let node = api.nodes.get(identifier: target.identifier, name: target.name, depth: .all)
            .expectsOne { self.wait(for: [$0], timeout: 8) }
        XCTAssertEqual(node.identifier, target.identifier)
        XCTAssertEqual(node.name, target.name)
        XCTAssertNotNil(node.subnodes)
        XCTAssertFalse(node.subnodes!.isEmpty)
        XCTAssertNotNil(node.markets)
    }

    /// Test the market search capabilities.
    func testMarketTermSearch() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)

        let markets = api.nodes.getMarkets(matching: "NZD")
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertFalse(markets.isEmpty)
        
        let now = Date()
        for market in markets {
            XCTAssertLessThanOrEqual(market.snapshot.date, now)
        }
    }
}
