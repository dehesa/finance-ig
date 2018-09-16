import ReactiveSwift
import Foundation

extension API {
    /// Returns all sub-nodes of the given node in the market navigation hierarchy.
    ///
    /// If no node identifier is given, the top-level nodes/markets are returned.
    /// - parameter nodeId: The identifier for the targeted node under which the nodes/markets returned in the result are.
    /// - returns: Signal giving the nodes and/or markets directly under the navigation node given as the parameter.
    public func navigationNodes(underNode nodeId: String? = nil) -> SignalProducer<(nodes: [API.Response.Node], markets: [API.Response.Node.Market]),API.Error> {
        return self.makeRequest(.get, "marketnavigation/\(nodeId ?? "")", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (n: API.Response.Navigation) in (n.nodes, n.markets) }
    }
    
    /// Returns all markets matching the search term.
    ///
    /// The search term cannot be an empty string.
    /// - parameter searchTerm: The term to be used in the search. This parameter is mandatory and cannot be empty.
    public func markets(searchTerm: String) -> SignalProducer<[API.Response.Node.Market],API.Error> {
        return self.makeRequest(.get, "markets", version: 1, credentials: true, queries: {
                guard !searchTerm.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Search for markets failed! The search term cannot be empty")
                }
            
                return [URLQueryItem(name: "searchTerm", value: searchTerm)]
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.MarketSearch) in w.markets }
    }
}

extension API.Response {
    /// Market Search Response.
    fileprivate struct MarketSearch: Decodable {
        /// The wrapper container.
        let markets: [Node.Market]
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
    
    /// Navigation step.
    fileprivate struct Navigation: Decodable {
        /// Markets hierarchy node.
        let nodes: [Node]
        /// Markets data
        let markets: [Node.Market]
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.nodes = try container.decodeIfPresent([Node].self, forKey: .nodes) ?? []
            self.markets = try container.decodeIfPresent([Node.Market].self, forKey: .markets) ?? []
        }
        
        private enum CodingKeys: String, CodingKey {
            case nodes
            case markets
        }
    }
    
    /// Market hierarchy node.
    public struct Node: Decodable {
        /// Node identifier.
        public let identifier: String
        /// Node name.
        public let name: String
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        private enum CodingKeys: String, CodingKey {
            case identifier = "id", name
        }
    }
}

extension API.Response.Node {
    /// Market data.
    public struct Market: Decodable {
        /// The market's instrument.
        public let instrument: Instrument
        /// The market's prices.
        public let snapshot: Snapshot?
        /// Describes the current status of a given market
        public let status: API.Market.Status
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.status = try container.decode(API.Market.Status.self, forKey: .status)
            self.instrument = try Instrument(from: decoder)
            self.snapshot = try? Snapshot(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case status = "marketStatus"
        }
    }
}

extension API.Response.Node.Market {
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
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Double
        /// `true` if streaming prices are available, i.e. the market is tradeable and the client holds the necessary access permission.
        public let isAvailableByStreaming: Bool
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.epic = try container.decode(String.self, forKey: .epic)
            self.name = try container.decode(String.self, forKey: .name)
            self.type = try container.decode(API.Instrument.Kind.self, forKey: .type)
            self.expiry = try container.decodeIfPresent(API.Expiry.self, forKey: .expiry) ?? .none
            self.scalingFactor = try container.decode(Double.self, forKey: .scalingFactor)
            self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isPriceAvailableByStreaming)
        }
        
        private enum CodingKeys: String, CodingKey {
            case epic
            case name = "instrumentName"
            case type = "instrumentType"
            case expiry, scalingFactor
            case isPriceAvailableByStreaming = "streamingPricesAvailable"
        }
    }
    
    /// Market's prices.
    public struct Snapshot: Decodable {
        /// Time of the last price update.
        public let lastUpdate: Date
        /// Offer (buy) and bid (sell) price.
        public let price: (offer: Double, bid: Double, delay: Double)?
        /// Highest and lowest price of the day.
        public let range: (low: Double, high: Double)
        /// Price change net and percentage change on that day.
        public let change: (net: Double, percentage: Double)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.lastUpdate = try container.decode(Date.self, forKey: .lastUpdate, with: API.DateFormatter.time)
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
