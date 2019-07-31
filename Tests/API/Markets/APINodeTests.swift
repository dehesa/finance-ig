import XCTest
import ReactiveSwift
@testable import IG

final class APINavigationNodeTests: XCTestCase {
    /// Tests navigation nodes retrieval.
    func testNavigationNodes() {
        let api = Test.makeAPI(credentials: Test.credentials.api)

        let nodeId: String? = nil
        let nodeGivenName = "Root"
        
        let rootNode = try! api.nodes.get(identifier: nodeId, name: nodeGivenName, depth: .none).single()!.get()
        XCTAssertEqual(rootNode.identifier, nodeId)
        XCTAssertEqual(rootNode.name, nodeGivenName)
        
        XCTAssertFalse(rootNode.subnodes!.isEmpty)
        XCTAssertTrue(rootNode.subnodes!.allSatisfy { $0.identifier != nil && $0.name != nil && $0.subnodes == nil && $0.markets == nil })
        XCTAssertTrue(rootNode.markets!.isEmpty)
    }

    /// Test the market search capabilities.
    func testMarketTermSearch() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let markets = try! api.nodes.getMarkets(matching: "EURUSD").single()!.get()
        XCTAssertNil(markets.first(where: { $0.instrument.isOTCTradeable != nil || $0.instrument.lotSize != nil || $0.instrument.exchangeIdentifier != nil }))
    }
}
