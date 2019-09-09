@testable import IG
import ReactiveSwift
import XCTest

final class APINavigationNodeTests: XCTestCase {
    /// Tests navigation nodes retrieval.
    func testNavigationNodes() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api, targetQueue: nil)

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
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api, targetQueue: nil)
        
        let markets = try! api.nodes.getMarkets(matching: "NZD").single()!.get()
//        print(markets.map { $0.instrument.epic.rawValue + "\t->\t" + $0.instrument.name }.joined(separator: "\n"))
        XCTAssertNil(markets.first(where: { $0.instrument.isOTCTradeable != nil || $0.instrument.lotSize != nil || $0.instrument.exchangeIdentifier != nil }))
    }
    
//    func testExtractNodes() {
//        print()
//
//        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api)
//        let rootNode = try! api.nodes.get(identifier: "184730", name: "ETFs, ETCs & Trackers", depth: .all).single()!.get()
//
//        var parsing: [API.Node] = [rootNode]
//        var parsed: Set<String> = .init()
//
//        while let node = parsing.popLast() {
//            if let identifier = node.identifier {
//                guard parsed.insert(identifier).inserted else {
//                    print("\t\(identifier) has already been parsed")
//                    continue
//                }
//            }
//
//            if let subnodes = node.subnodes {
//                parsing.insert(contentsOf: subnodes, at: 0)
//            }
//
//            print(representation(node: node))
//        }
//
//        print()
//        print("\(parsed.count + 1) nodes has been parsed")
//        print()
//    }
//
//    private func representation(node: API.Node) -> String {
//        let (nothing, separator) = ("NULL", ", ")
//        var result = String()
//
//        if let identifier = node.identifier {
//            result.append(identifier)
//        } else {
//            result.append(nothing)
//        }
//
//        result.append(separator)
//
//        if let name = node.name {
//            result.append("\"")
//            result.append(name)
//            result.append("\"")
//        } else {
//            result.append(nothing)
//        }
//
//        result.append(separator)
//
//        if let subnodes = node.subnodes {
//            let value = subnodes.map { $0.identifier ?? nothing }.joined(separator: ",")
//            result.append("[\(value)]")
//        } else {
//            result.append(nothing)
//        }
//
//        result.append(separator)
//
//        if let markets = node.markets {
//            let value = markets.map { "\"\($0.instrument.epic.rawValue)\"" }.joined(separator: ",")
//            result.append("[\(value)]")
//        } else {
//            result.append(nothing)
//        }
//        return result
//    }
}
