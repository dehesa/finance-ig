import XCTest
import ReactiveSwift
@testable import IG

final class APIPlaygroundTests: XCTestCase {
    func testThing() {
        print("--------------------------------------------\n")
        let expectation = self.expectation(description: "Timeout occurred")
        
        SignalProducer<String,Never> { (generator, lifetime) in
            let values = ["A", "B", "C", "D", "E"]
            let times  = [  0,   1,   2,   3,   4]

            let queue = DispatchQueue.global()
            zip(values, times).forEach { (val, secs) in
                queue.asyncAfter(deadline: .now() + .seconds(secs)) {
                    print(val)
                    generator.send(value: val)
                }
            }

            queue.asyncAfter(deadline: .now() + .seconds(times.last!) + .milliseconds(50)) {
                generator.sendCompleted()
            }
        }.flatMap(.merge) { (string) -> SignalProducer<String,Never> in
            return SignalProducer { (generator, lifetime) in
                let queue = DispatchQueue.global()
                for time in [0, 1, 2, 3] {
                    queue.asyncAfter(deadline: .now() + .seconds(time)) {
                        generator.send(value: string + " - \(time)")
                    }
                }
                
                queue.asyncAfter(deadline: .now() + .seconds(3) + .milliseconds(50)) {
                    generator.sendCompleted()
                }
            }.on(event: { (event) in
                if case .value(let v) = event {
                    print("\t\(v)")
                } else {
                    print("\t\(string) \(event)")
                }
            })
        }.start { (event) in
            switch event {
            case .value(_): break
            case .completed:
                print("Signal completed")
                expectation.fulfill()
            case .interrupted: print("Signal interrupted")
            case .failed(_): print("Signal interrupted")
            }
        }
        
        self.waitForExpectations(timeout: 10) { (error) in
            var result = "Expectation finished"
            if let _ = error {
                result.append(", but an error occurred...")
            }
            print(result)
            print("\n--------------------------------------------")
        }
    }
}

//final class APIPlaygroundTests: APITestCase {
//    func testRetrieveAllNodes() {
//        var nodos = Set<Nodo>()
//        let endpoint = self.signalNodo(spacing: 1100).on(value: { nodos.insert($0) })
//
//        self.test("Retrieving all nodes", endpoint, signingProcess: .certificate, timeout: 60 * 60 * 4) { (error) in
//            let data: Data
//            do {
//                let array = Array(nodos)
//                data = try JSONEncoder().encode(array)
//            } catch let error {
//                print("Couldn't parse to JSON! Error: \n\(error)\n")
//                return print(nodos)
//            }
//            let attachment = XCTAttachment(data: data).set { $0.lifetime = .keepAlways }
//            self.add(attachment)
//        }
//    }
//
//    func signalNodo(spacing milliseconds: UInt) -> SignalProducer<Nodo,API.Error> {
//        return SignalProducer { (input, _) in
//            var toSearch: [Nodo] = [Nodo(identifier: "Top", name: "Top of tree")]
//            var alreadySearched: Set<String> = []
//
//            var handler: ((Signal<(nodes: [API.Response.Node], markets: [API.Response.Node.Market]), API.Error>.Event) -> Void)! = nil
//            handler = { (event) in
//                switch event {
//                case .value(let value):
//                    let nodo = toSearch.removeFirst()
//                    nodo.complete(with: value)
//                    alreadySearched.insert(nodo.identifier)
//
//                    toSearch.append(contentsOf:value.nodes
//                        .filter { !alreadySearched.contains($0.identifier) }
//                        .map { Nodo(identifier: $0.identifier, name: $0.name) } )
//                    input.send(value: nodo)
//                case .completed:
//                    guard !toSearch.isEmpty else {
//                        return input.sendCompleted()
//                    }
//                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(milliseconds))) {
//                        self.api.navigationNodes(underNode: toSearch.first!.identifier).start(handler)
//                    }
//                case .failed(let error): input.send(error: error)
//                case .interrupted: input.sendInterrupted()
//                }
//
//            }
//
//            self.api.navigationNodes().start(handler)
//        }
//    }
//
//    func testStuff() {
//        let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!.appendingPathComponent("File.json")
//        let data = FileManager.default.contents(atPath: url.path)!
//
//        let file = try! JSONDecoder().decode(File.self, from: data)
//        print("Nodes: \(file.nodes.count)")
//        print("Markets: \(file.markets.count)")
//    }
//}
//
//fileprivate final class File: Codable {
//    let nodes: Set<Node>
//    let markets: Set<Market>
//    let top: Node
//}
//
//fileprivate struct Navigator {
//    let file: File
//    private(set) var path: [String]
//
//    init(file: File) {
//        self.file = file
//        self.path = [file.top.identifier]
//    }
//
//    var location: Node {
//        guard let identifier = self.path.last,
//              let result = file.nodes.first(where: { $0.identifier == identifier }) else { fatalError() }
//        return result
//    }
//
//    mutating func toChild(with childId: String, print: Bool = false) -> Node? {
//        guard let _ = self.location.children?.first(where: { $0 == childId }),
//              let node = file.nodes.first(where: { $0.identifier == childId }) else { return nil }
//        self.path.append(childId)
//        return node
//    }
//
//    mutating func toParent(print: Bool = false) -> Node {
//        let index = self.path.endIndex - 2
//        guard index >= self.path.startIndex else {
//            self.path = [file.top.identifier]
//            return self.location
//        }
//
//        let parentId = self.path[index]
//        guard let result = file.nodes.first(where: { $0.identifier == parentId }) else { fatalError() }
//
//        let _ = self.path.removeLast()
//        return result
//    }
//
//    func children(print: Bool = false) -> Set<Node> {
//        guard var childIds = self.location.children, !childIds.isEmpty else { return Set() }
//
//        var result = Set<Node>(minimumCapacity: childIds.count)
//        for node in file.nodes where childIds.contains(node.identifier) {
//            childIds.remove(node.identifier)
//            result.insert(node)
//            if childIds.isEmpty { break }
//        }
//        return result
//    }
//
//    func markets(print: Bool = false) -> Set<Market> {
//        guard var epics = self.location.marketEpics, !epics.isEmpty else { return Set() }
//
//        var result = Set<Market>(minimumCapacity: epics.count)
//        for market in file.markets where epics.contains(market.epic) {
//            epics.remove(market.epic)
//            result.insert(market)
//            if epics.isEmpty { break }
//        }
//        return result
//    }
//}
//
//fileprivate final class Node: Codable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
//    let identifier: String
//    let name: String
//    private(set) var children: Set<String>? = nil
//    private(set) var marketEpics: Set<String>? = nil
//
//    init(identifier: String, name: String) {
//        self.identifier = identifier
//        self.name = name
//    }
//
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(self.identifier, forKey: .identifier)
//        try container.encode(self.name, forKey: .name)
//        if let nodes = self.children, !nodes.isEmpty {
//            try container.encode(nodes, forKey: .children)
//        }
//        if let markets = self.marketEpics, !markets.isEmpty {
//            try container.encode(markets, forKey: .marketEpics)
//        }
//    }
//
//    private enum CodingKeys: String, CodingKey {
//        case identifier = "id"
//        case name
//        case children = "nodes"
//        case marketEpics = "markets"
//    }
//
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(self.identifier)
//    }
//
//    static func == (lhs: Node, rhs: Node) -> Bool {
//        return lhs.identifier == rhs.identifier
//    }
//
//    var description: String {
//        return "\(self.identifier): \(self.name) | \(self.children?.count ?? 0) subnodes, \(self.marketEpics?.count ?? 0) markets"
//    }
//
//    var debugDescription: String {
//        let subnodes = self.children?.joined(separator: ", ")
//        let submarkets = self.marketEpics?.joined(separator: ", ")
//        return """
//        identifier: \(self.identifier)
//        name: \(self.name)
//        subnodes: \(subnodes.map { "[" + $0 + "]" } ?? "null")
//        markets: \(submarkets.map { "[" + $0 + "]" } ?? "null")
//        """
//    }
//}
//
//fileprivate final class Market: Codable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
//    let epic: String
//    let name: String
//    let type: API.Instrument
//    let expiry: API.Expiry
//    let isAvailableByStreaming: Bool
//    let status: API.Market.Status
//
//    init(_ market: API.Response.Node.Market) {
//        let instrument = market.instrument
//        self.epic = instrument.epic
//        self.name = instrument.name
//        self.type = instrument.type
//        self.expiry = instrument.expiry
//        self.isAvailableByStreaming = instrument.isAvailableByStreaming
//        self.status = market.status
//    }
//
//    private enum CodingKeys: String, CodingKey {
//        case epic, name, type, expiry, status
//        case isAvailableByStreaming = "streaming"
//    }
//
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(self.epic)
//    }
//
//    static func == (lhs: Market, rhs: Market) -> Bool {
//        return lhs.epic == rhs.epic
//    }
//
//    var description: String {
//        return "\(self.epic): \(self.name) [\(self.type), \(self.status), \(self.expiry)] streaming: \(self.isAvailableByStreaming)"
//    }
//
//    var debugDescription: String {
//        return """
//        epic: \(self.epic)
//        name: \(self.name)
//        type: \(self.type), \(self.expiry)
//        streaming: \(self.isAvailableByStreaming)
//        status: \(self.status)
//        """
//    }
//}
