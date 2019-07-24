import ReactiveSwift
import Foundation

extension API.Request.Nodes {
    
    // MARK: GET Aggregator
    
    /// Returns the navigation node with the given id and all the children till a specified depth.
    /// - attention: For depths bigger than 0, several endpoints are hit; thus, the callback may be received later on in the future.
    /// - parameter identifier: The identifier for the targeted node. If `nil`, the top-level nodes are returned.
    /// - parameter name: The name for the targeted name. If `nil`, the name of the node is not set on the returned `Node` instance.
    /// - parameter depth: The depth at which the tree will be travelled.  A negative integer will default to `0`.
    /// - returns: Signal giving the nodes and/or markets directly under the navigation node given as the parameter.
    public func get(identifier: String?, name: String? = nil, depth: Self.Depth = .none) -> SignalProducer<API.Node,API.Error> {
        let layers = depth.value
        guard layers > 0 else {
            return self.get(node: .init(identifier: identifier, name: name))
        }
        
        return self.iterate(node: .init(identifier: identifier, name: name), depth: layers)
    }

    // MARK: GET /markets/{searchTerm}
    
    /// Returns all markets matching the search term.
    ///
    /// The search term cannot be an empty string.
    /// - parameter searchTerm: The term to be used in the search. This parameter is mandatory and cannot be empty.
    public func getMarkets(matching searchTerm: String) -> SignalProducer<[API.Node.Market],API.Error> {
        return SignalProducer(api: self.api) { (_) -> String in
            guard !searchTerm.isEmpty else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "Search for markets failed! The search term cannot be empty")
            }
            return searchTerm
        }.request(.get, "markets", version: 1, credentials: true, queries: { (_,searchTerm) in
            [URLQueryItem(name: "searchTerm", value: searchTerm)]
        }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON { (request, response) in
                guard let dateString = response.allHeaderFields[API.HTTP.Header.Key.date.rawValue] as? String,
                      let date = API.DateFormatter.humanReadableLong.date(from: dateString) else {
                    throw API.Error.invalidResponse(response, request: request, data: nil, underlyingError: nil, message: "The response date couldn't be inferred.")
                }
                
                let decoder = JSONDecoder()
                decoder.userInfo[API.JSON.DecoderKey.responseDate] = date
                return decoder
            }
            .map { (w: Self.WrapperSearch) in w.markets }
    }

    // MARK: GET /marketnavigation/{nodeId}
    
    /// Returns the navigation node described by the given entity.
    /// - parameter node: The entity targeting a specific node. Only the identifier is used for identification purposes.
    /// - returns: Signal returning the node as a value and completing right after that.
    private func get(node: API.Node) -> SignalProducer<API.Node,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "marketnavigation/\(node.identifier ?? "")", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON { (_, responseHeader) -> JSONDecoder in
                let decoder = JSONDecoder()
                decoder.userInfo[API.JSON.DecoderKey.responseHeader] = responseHeader
                
                if let identifier = node.identifier {
                    decoder.userInfo[API.JSON.DecoderKey.nodeIdentifier] = identifier
                }
                if let name = node.name {
                    decoder.userInfo[API.JSON.DecoderKey.nodeName] = name
                }
                
                return decoder
            }
    }
    
    // MARK: GET Recursive
    
    /// Returns the navigation node indicated by the given node argument as well as all its children till a given depth.
    /// - parameter node: The entity targeting a specific node. Only the identifier is used for identification purposes.
    /// - parameter depth: The depth at which the tree will be travelled.  A negative integer will default to `0`.
    /// - returns: Signal returning the node as a value and completing right after that.
    private func iterate(node: API.Node, depth: Int) -> SignalProducer<API.Node,API.Error> {
        return SignalProducer { (generator, lifetime) in
            var parent = node
            var detacher: Disposable? = nil
            
            var childrenIterator: ((_ index: Int, _ depth: Int) -> ())! = nil
            
            detacher = lifetime += self.get(node: node).start { (event) in
                switch event {
                case .value(let node):
                    parent = node;
                    return
                case .completed:
                    detacher?.dispose()
                    detacher = nil
                    break
                case .failed(let error):
                    return generator.send(error: error)
                case .interrupted:
                    return generator.sendInterrupted()
                }
                
                let inverseCounter = depth - 1
                guard inverseCounter >= 0,
                      let subnodes = parent.subnodes, !subnodes.isEmpty else {
                    generator.send(value: parent)
                    generator.sendCompleted()
                    return
                }
                
                childrenIterator(0, inverseCounter)
            }
            
            childrenIterator = { (index, depth) in
                detacher = lifetime += self.iterate(node: parent.subnodes![index], depth: depth).start { (event) in
                    switch event {
                    case .value(let node):
                        parent.subnodes![index] = node
                        return
                    case .completed:
                        detacher?.dispose()
                        detacher = nil
                        break
                    case .failed(let error):
                        return generator.send(error: error)
                    case .interrupted:
                        return generator.sendInterrupted()
                    }
                    
                    let nextChild = index + 1
                    guard nextChild < parent.subnodes!.count else {
                        generator.send(value: parent)
                        generator.sendCompleted()
                        return
                    }
                    
                    childrenIterator(nextChild, depth)
                }
            }
        }
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to navigation nodes.
    public struct Nodes {
        /// Pointer to the actual API instance in charge of calling the endpoints.
        fileprivate unowned let api: API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        init(api: API) {
            self.api = api
        }
    }
}

// MARK: Request Entities

extension API.Request.Nodes {
    /// Express the depth of a computed tree.
    public enum Depth: ExpressibleByNilLiteral, ExpressibleByIntegerLiteral {
        case none
        case layers(UInt)
        case all
        
        public init(nilLiteral: ()) {
            self = .none
        }
        
        public init(integerLiteral value: UInt) {
            if value == 0 {
                self = .none
            } else {
                self = .layers(value)
            }
        }
        
        fileprivate var value: Int {
            switch self {
            case .none:
                return 0
            case .layers(let value):
                return Int(clamping: value)
            case .all:
                return Int.max
            }
        }
    }
}

// MARK: Response Entities

extension API.JSON.DecoderKey {
    /// Key for JSON decoders under which a node identifier will be stored.
    fileprivate static let nodeIdentifier = CodingUserInfoKey(rawValue: "nodeId")!
    /// Key for JSON decoders under which a node name will be stored.
    fileprivate static let nodeName = CodingUserInfoKey(rawValue: "nodeName")!
}

extension API.Request.Nodes {
    private struct WrapperSearch: Decodable {
        let markets: [API.Node.Market]
    }
}

extension API {
    /// Node within the Broker platform markets organization.
    public struct Node: Decodable {
        /// Node identifier.
        /// - note: The top of the tree will return `nil` for this property.
        public let identifier: String?
        /// Node name.
        public var name: String?
        /// The children nodes (subnodes) of `self`.
        public internal(set) var subnodes: [Self]?
        /// The markets organized under `self`
        public internal(set) var markets: [Self.Market]?
        
        fileprivate init(identifier: String?, name: String?) {
            self.identifier = identifier
            self.name = name
            self.subnodes = nil
            self.markets = nil
        }
        
        public init(from decoder: Decoder) throws {
            self.identifier = decoder.userInfo[API.JSON.DecoderKey.nodeIdentifier] as? String
            self.name = decoder.userInfo[API.JSON.DecoderKey.nodeName] as? String
            
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            var subnodes: [API.Node] = []
            if container.contains(.nodes), try !container.decodeNil(forKey: .nodes) {
                var array = try container.nestedUnkeyedContainer(forKey: .nodes)
                while !array.isAtEnd {
                    let nodeContainer = try array.nestedContainer(keyedBy: Self.CodingKeys.ChildKeys.self)
                    let id = try nodeContainer.decode(String.self, forKey: .id)
                    let name = try nodeContainer.decode(String.self, forKey: .name)
                    subnodes.append(.init(identifier: id, name: name))
                }
            }
            self.subnodes = subnodes
            
            if container.contains(.markets), try !container.decodeNil(forKey: .markets) {
                self.markets = try container.decode(Array<Self.Market>.self, forKey: .markets)
            } else {
                self.markets = []
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case nodes, markets
            
            enum ChildKeys: String, CodingKey {
                case id, name
            }
        }
    }
}
