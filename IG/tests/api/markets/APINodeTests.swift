import IG
import ConbiniForTesting
import XCTest

final class APINavigationNodeTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests navigation nodes retrieval.
    func testNavigationRootNodes() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
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
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
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
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
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
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)

        let markets = api.nodes.getMarkets(matching: "NZD").expectsOne(timeout: 2, on: self)
        XCTAssertFalse(markets.isEmpty)
        
        let now = Date()
        for market in markets {
            XCTAssertLessThanOrEqual(market.snapshot.date, now)
        }
    }
}
