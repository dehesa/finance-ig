import ReactiveSwift
import Foundation

// MARK: - GET /marketnavigation/{nodeId}

extension API.Request.Nodes {
    /// Returns the navigation node with the given id and all the children till a specified depth.
    /// - attention: For depths bigger than 0, several endpoints are hit; thus, the callback may be received later on in the future.
    /// - parameter identifier: The identifier for the targeted node. If `nil`, the top-level nodes are returned.
    /// - parameter name: The name for the targeted name. If `nil`, the name of the node is not set on the returned `Node` instance.
    /// - parameter depth: The depth at which the tree will be travelled.  A negative integer will default to `0`.
    /// - returns: Signal giving the nodes and/or markets directly under the navigation node given as the parameter.
    public func get(identifier: String?, name: String? = nil, depth: Depth = .none) -> SignalProducer<API.Node,API.Error> {
        let layers = depth.value
        guard layers > 0 else {
            return self.get(node: .init(identifier: identifier, name: name))
        }
        
        return self.iterate(node: .init(identifier: identifier, name: name), depth: layers)
    }
}

// MARK: - GET /markets/{searchTerm}

extension API.Request.Nodes {
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
            .decodeJSON()
            .map { (w: MarketSearch) in w.markets }
    }
}

// MARK: - Supporting functionality

extension API.Request.Nodes {
    /// Returns the navigation node described by the given entity.
    /// - parameter node: The entity targeting a specific node. Only the identifier is used for identification purposes.
    /// - returns: Signal returning the node as a value and completing right after that.
    private func get(node: API.Node) -> SignalProducer<API.Node,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "marketnavigation/\(node.identifier ?? "")", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON { (_,_) -> JSONDecoder in
                let decoder = JSONDecoder()
                if let identifier = node.identifier {
                    decoder.userInfo[API.JSON.DecoderKey.nodeIdentifier] = identifier
                }
                if let name = node.name {
                    decoder.userInfo[API.JSON.DecoderKey.nodeName] = name
                }
                return decoder
            }
    }
    
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
    
    private struct MarketSearch: Decodable {
        let markets: [API.Node.Market]
    }
}

extension API.JSON.DecoderKey {
    /// Key for JSON decoders under which a node identifier will be stored.
    fileprivate static let nodeIdentifier = CodingUserInfoKey(rawValue: "nodeId")!
    /// Key for JSON decoders under which a node name will be stored.
    fileprivate static let nodeName = CodingUserInfoKey(rawValue: "nodeName")!
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
        public internal(set) var subnodes: [API.Node]?
        /// The markets organized under `self`
        public internal(set) var markets: [API.Node.Market]?
        
        fileprivate init(identifier: String?, name: String?) {
            self.identifier = identifier
            self.name = name
            self.subnodes = nil
            self.markets = nil
        }
        
        public init(from decoder: Decoder) throws {
            self.identifier = decoder.userInfo[API.JSON.DecoderKey.nodeIdentifier] as? String
            self.name = decoder.userInfo[API.JSON.DecoderKey.nodeName] as? String
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            var subnodes: [API.Node] = []
            if container.contains(.nodes), try !container.decodeNil(forKey: .nodes) {
                var array = try container.nestedUnkeyedContainer(forKey: .nodes)
                while !array.isAtEnd {
                    let nodeContainer = try array.nestedContainer(keyedBy: CodingKeys.ChildKeys.self)
                    let id = try nodeContainer.decode(String.self, forKey: .id)
                    let name = try nodeContainer.decode(String.self, forKey: .name)
                    subnodes.append(.init(identifier: id, name: name))
                }
            }
            self.subnodes = subnodes
            
            if container.contains(.markets), try !container.decodeNil(forKey: .markets) {
                self.markets = try container.decode([API.Node.Market].self, forKey: .markets)
            } else {
                self.markets = nil
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

extension API.Node {
    /// Market data hanging from a hierarchical node.
    public struct Market: Decodable {
        /// Describes the current status of a given market
        public let status: API.Market.Status
        /// The market's instrument.
        public let instrument: API.Node.Market.Instrument
        /// The market's prices.
        public let snapshot: API.Node.Market.Snapshot
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.status = try container.decode(API.Market.Status.self, forKey: .status)
            self.instrument = try .init(from: decoder)
            self.snapshot = try .init(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case status = "marketStatus"
        }
    }
}

extension API.Node.Market {
    /// Market's instrument properties.
    public struct Instrument: Decodable {
        /// Instrument epic identifier.
        public let epic: String
        /// Instrument name.
        public let name: String
        /// Instrument type.
        public let type: API.Instrument.Kind
        /// Instrument expiry period.
        public let expiry: API.Expiry
        /// Minimum amount of unit that an instrument can be dealt in the market. It's the relationship between unit and the amount per point.
        /// - note: This property is set when querying nodes, but `nil` when querying markets.
        public let lotSize: UInt?
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Double
        /// `true` if streaming prices are available, i.e. the market is tradeable and the client holds the necessary access permission.
        public let isAvailableByStreaming: Bool
        /// `true` if Over-The-Counter tradeable.
        /// - note: This property is set when querying nodes, but `nil` when querying markets.
        public let isOTCTradeable: Bool?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.epic = try container.decode(String.self, forKey: .epic)
            self.name = try container.decode(String.self, forKey: .name)
            self.type = try container.decode(API.Instrument.Kind.self, forKey: .type)
            self.expiry = try container.decodeIfPresent(API.Expiry.self, forKey: .expiry) ?? .none
            self.lotSize = try container.decodeIfPresent(UInt.self, forKey: .lotSize)
            self.scalingFactor = try container.decode(Double.self, forKey: .scalingFactor)
            self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isAvailableByStreaming)
            self.isOTCTradeable = try container.decodeIfPresent(Bool.self, forKey: .isOTCTradeable)
        }
        
        private enum CodingKeys: String, CodingKey {
            case epic, name = "instrumentName"
            case type = "instrumentType"
            case expiry, lotSize, scalingFactor
            case isAvailableByStreaming = "streamingPricesAvailable"
            case isOTCTradeable = "otcTradeable"
        }
    }
}

extension API.Node.Market {
    /// Market's prices.
    public struct Snapshot: Decodable {
        /// Time of the last price update.
        public let date: Date
        /// Offer (buy) and bid (sell) price. Also the price delay is marked in minutes.
        public let price: (offer: Double, bid: Double, delay: Double)?
        /// Highest and lowest price of the day.
        public let range: (low: Double, high: Double)
        /// Price change net and percentage change on that day.
        public let change: (net: Double, percentage: Double)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.date = try container.decode(Date.self, forKey: .lastUpdate, with: API.DateFormatter.time)
            let low = try container.decode(Double.self, forKey: .low)
            let high = try container.decode(Double.self, forKey: .high)
            self.range = (low, high)
            let netChange = try container.decode(Double.self, forKey: .netChange)
            let percentageChange = try container.decode(Double.self, forKey: .percentageChange)
            self.change = (netChange, percentageChange)
            
            if let offer = try container.decodeIfPresent(Double.self, forKey: .offer),
                let bid = try container.decodeIfPresent(Double.self, forKey: .bid),
                let delay = try container.decodeIfPresent(Double.self, forKey: .delay) {
                self.price = (offer, bid, delay)
            } else {
                self.price = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case lastUpdate = "updateTimeUTC"
            case offer, bid, delay = "delayTime"
            case high, low
            case netChange, percentageChange
        }
    }
}
