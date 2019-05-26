import ReactiveSwift
import Foundation

extension API {
    /// Creates a new position.
    ///
    /// This endpoint creates a "transient" position (identified by the returned deal reference). The position is not really open till the server confirms the "transient" position and gives the user a deal identifier.
    /// - parameter request: Data for the new position, with some in-client data validation.
    /// - returns: The transient deal reference (for an unconfirmed trade).
    public func createPosition(_ request: API.Request.Position.Creation) -> SignalProducer<String,API.Error> {
        return self.makeRequest(.post, "positions/otc", version: 2, credentials: true, body: {
                return (.json, try API.Codecs.jsonEncoder().encode(request))
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.Position.ReferenceWrapper) in w.dealReference }
    }

    /// Edits an opened position (identified by the `dealId`).
    ///
    /// This endpoint modifies an openned position. The returned refence is not considered as taken into effect until the server confirms the "transient" position reference and give the user a deal identifier.
    /// - parameter dealId: A permanent deal reference for a confirmed trade.
    /// - parameter limit: Optional new price limit level at which the user will be happy taking profits.
    /// - parameter stop: Optional new price stop level at which the user won't take more losses.
    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
    public func updatePosition(identifier dealId: String, limit: Double? = nil, stop: API.Request.Position.Update.Stop? = nil) -> SignalProducer<String,API.Error> {
        return self.makeRequest(.put, "positions/otc/\(dealId)", version: 2, credentials: true, queries: {
                guard !dealId.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "Position update failed! The deal identifier cannot be empty.") }
                return []
            }, body: {
                guard let body = API.Request.Position.Update(limit: limit, stop: stop) else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Position update failed! No parameters were provided.")
                }
                return (.json, try API.Codecs.jsonEncoder().encode(body))
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.Position.ReferenceWrapper) in w.dealReference }
    }

    /// Closes one or more positions.
    /// - parameter request: A filter to match the positions to be deleted.
    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
    public func deletePositions(_ request: API.Request.Position.Deletion) -> SignalProducer<String,API.Error> {
        return self.makeRequest(.post, "positions/otc", version: 1, credentials: true, headers: [._method: API.HTTP.Method.delete.rawValue], body: {
                return (.json, try API.Codecs.jsonEncoder().encode(request))
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.Position.ReferenceWrapper) in w.dealReference }
    }
}

// MARK: -

extension API.Request {
    /// List of OTC position requests.
    public enum Position { }
}

extension API.Request.Position {
    /// Information needed to create a OTC position.
    public struct Creation: Encodable {
        /// A user-defined reference identifying the submission of the order.
        ///
        /// Example of deal reference: `RV1JZ1CHMWG2KB`
        public let reference: String?
        /// Instrument epic identifer.
        public let epic: String
        /// Instrument expiration date.
        ///
        /// The date (and sometimes time) at which a spreadbet or CFD will automatically close against some predefined market value should the bet remain open beyond its last dealing time. Some CFDs do not expire.
        public let expiry: API.Expiry
        /// The currency code (3 letters).
        public let currency: String
        /// Describes how the user's order must be executed.
        public let order: API.Request.Position.Order
        /// Deal size.
        ///
        /// Precision shall not be more than 12 decimal places.
        public let size: Double
        /// Deal direction
        public let direction: API.Position.Direction
        /// The instrument price at which price is the user buying or selling.
        public let level: Double?
        /// Optional boundaries from the trade's buy/sell price at which the user doesn't want to win/lose more money.
        public let boundaries: API.Request.Position.Boundaries
        /// Boolean indicating whether "force open" is required.
        ///
        /// Enabling force open when creating a new position (or working order) will enable a second position to be opened on a market. Working orders (orders to open) have this set to true by default.
        public let requiresForceOpen: Bool  // TODO: On the [API reference](https://labs.ig.com/rest-trading-api-reference/service-detail?id=542) they specified forceOpen constraint that don't match what it they are actually doing (by sniffing their packages).
        
        /// Market order initializer.
        public init(marketOrder strategy: Order.Strategy, epic: String, expiry: API.Expiry = .none, currency: String, size: Double, direction: API.Position.Direction, boundaries: API.Request.Position.Boundaries? = nil, forceOpen: Bool = false, reference: String? = nil) {
            self.reference = reference
            self.epic = epic
            self.expiry = expiry
            self.currency = currency
            self.order = .init(.market, strategy: strategy)
            self.size = size
            self.direction = direction
            self.level = nil
            self.boundaries = boundaries ?? Boundaries()
            self.requiresForceOpen = forceOpen
        }
        
        /// Limit order initializer.
        public init(limitOrder strategy: Order.Strategy, epic: String, expiry: API.Expiry = .none, currency: String, size: Double, direction: API.Position.Direction, level: Double, boundaries: API.Request.Position.Boundaries? = nil, forceOpen: Bool = false, reference: String? = nil) {
            self.reference = reference
            self.epic = epic
            self.expiry = expiry
            self.currency = currency
            self.order = .init(.limit, strategy: strategy)
            self.size = size
            self.direction = direction
            self.level = level
            self.boundaries = boundaries ?? Boundaries()
            self.requiresForceOpen = forceOpen
        }
        
        /// Quote order initializer.
        public init(quoteOrder: (Order.Strategy, quoteId: String), epic: String, expiry: API.Expiry = .none, currency: String, size: Double, direction: API.Position.Direction, level: Double, boundaries: API.Request.Position.Boundaries? = nil, forceOpen: Bool = false, reference: String? = nil) {
            self.reference = reference
            self.epic = epic
            self.expiry = expiry
            self.currency = currency
            self.order = .init(.quote(id: quoteOrder.quoteId), strategy: quoteOrder.0)
            self.size = size
            self.direction = direction
            self.level = level
            self.boundaries = boundaries ?? Boundaries()
            self.requiresForceOpen = forceOpen
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.reference, forKey: .reference)
            try container.encode(self.epic, forKey: .epic)
            try container.encode(self.currency, forKey: .currency)
            try self.order.encode(to: encoder)
            try container.encode(self.size, forKey: .size)
            try container.encode(self.direction, forKey: .direction)
            try container.encodeIfPresent(self.level, forKey: .level)
            try self.boundaries.encode(to: encoder)
            try container.encode(self.requiresForceOpen, forKey: .requiresForceOpen)
            try container.encode(self.expiry, forKey: .expiry)
        }
        
        private enum CodingKeys: String, CodingKey {
            case reference = "dealReference"
            case epic, expiry
            case currency = "currencyCode"
            case size, direction, level
            case requiresForceOpen = "forceOpen"
        }
    }
}

extension API.Request.Position {
    /// Information needed to update a confirmed position.
    public struct Update: Encodable {
        /// The limit level at which the user is happy with his/her profits.
        ///
        /// This number (if existant) represents the absolute price value.
        fileprivate let limit: Double?
        /// The stop level at which the user doesn't want to take more losses.
        fileprivate let stop: Stop?
        /// The stop is represented by an absolute level price and an optional trailing stop (marked by a relative distance and step increment).
        public typealias Stop = (level: Double, trailing: (distance: Double, increment: Double)?)
        
        /// Designated initializer.
        /// - parameter limit: Price level at which the user is happy with his/her profits.
        /// - parameter stop: Price level at which the user doesn't want to take more losses.
        /// - returns: If both parameters are `nil`, then `nil` will be returned. Otherwise, the instantiated struct will be created.
        fileprivate init?(limit: Double?, stop: Stop?) {
            guard (limit != nil) || (stop != nil) else { return nil }
            self.limit = limit
            self.stop = stop
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(self.limit, forKey: .limit)
            
            guard let stop = self.stop else {
                return try container.encode(false, forKey: .isTrailingStop)
            }
            
            try container.encode(stop.level, forKey: .stop)
            guard let trailing = stop.trailing else {
                return try container.encode(false, forKey: .isTrailingStop)
            }
            
            try container.encode(true, forKey: .isTrailingStop)
            try container.encode(trailing.distance, forKey: .trailingStopDistance)
            try container.encode(trailing.increment, forKey: .trailingStopIncrement)
        }
        
        private enum CodingKeys: String, CodingKey {
            case limit = "limitLevel"
            case stop = "stopLevel"
            case isTrailingStop = "trailingStop"
            case trailingStopDistance
            case trailingStopIncrement
        }
    }
}

extension API.Request.Position {
    /// Information needed to delete a confirmed position.
    public struct Deletion: Encodable {
        /// The type of deletion to be processed.
        public let type: Kind
        /// Describes how the user's order must be executed.
        public let order: API.Request.Position.Order
        /// Deal size.
        ///
        /// Precision shall not be more than 12 decimal places.
        public let size: Double
        /// Deal direction
        public let direction: API.Position.Direction
        /// Closing deal price.
        public let level: Double?
        
        /// Market order filter.
        public init(_ type: Kind, marketOrder strategy: API.Request.Position.Order.Strategy, size: Double, direction: API.Position.Direction) {
            self.type = type
            self.order = .init(.market, strategy: strategy)
            self.size = size
            self.direction = direction
            self.level = nil
        }
        
        /// Limit order filter.
        public init(_ type: Kind, limitOrder strategy: API.Request.Position.Order.Strategy, size: Double, direction: API.Position.Direction, level: Double) {
            self.type = type
            self.order = .init(.limit, strategy: strategy)
            self.size = size
            self.direction = direction
            self.level = level
        }
        
        /// Quote order filter.
        public init(_ type: Kind, quoteOrder: (Order.Strategy, quoteId: String), size: Double, direction: API.Position.Direction, level: Double) {
            self.type = type
            self.order = .init(.quote(id: quoteOrder.quoteId), strategy: quoteOrder.0)
            self.size = size
            self.direction = direction
            self.level = level
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self.type {
            case .byIdentifier(let dealId):
                try container.encode(dealId, forKey: .identifier)
            case .byEpic(let epic, let expiry):
                try container.encode(epic, forKey: .epic)
                try container.encode(expiry, forKey: .expiry)
            }
            
            try self.order.encode(to: encoder)
            try container.encode(self.size, forKey: .size)
            try container.encode(self.direction, forKey: .direction)
            try container.encodeIfPresent(self.level, forKey: .level)
        }
        
        /// The user can delete positions marked by deal identifiers or by epic.
        public enum Kind {
            /// Permanent deal identifier for a confirmed trade.
            case byIdentifier(String)
            /// Instrument epic identifier.
            case byEpic(String, expiry: API.Expiry)
        }
        
        private enum CodingKeys: String, CodingKey {
            case identifier = "dealId"
            case epic, expiry
            case size, direction, level
        }
    }
}

extension API.Request.Position {
    /// Describes how the user's order must be executed.
    public struct Order: Encodable {
        /// Describes the order level model to be used for a position operation.
        public let type: Kind
        /// The time in force determines the order fill strategy.
        public let strategy: Strategy
        
        /// Hidden initializer.
        fileprivate init(_ type: Kind, strategy: Strategy) {
            self.type = type
            self.strategy = strategy
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.type.rawValue, forKey: .order)
            try container.encode(self.strategy, forKey: .orderFillStrategy)
            if case .quote(let quoteId) = self.type {
                try container.encode(quoteId, forKey: .quoteId)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case order = "orderType"
            case quoteId
            case orderFillStrategy = "timeInForce"
        }
        
        /// Order level model for the position operation.
        public enum Kind {
            /// A market order is an instruction to buy or sell at the best available price for the size of your order.
            ///
            /// When using this type of order you choose the size and direction of your order, but not the price (a level cannot be specified).
            /// - note: Not applicable to BINARY instruments.
            case market
            /// A limit fill or kill order is an instruction to buy or sell in a specified size within a specified price limit, which is either filled completely or rejected.
            ///
            /// Provided the market price is within the specified limit and there is sufficient volume available, the order will be filled at the prevailing market price.
            ///
            /// The entire order will be rejected if:
            /// - The market price is outside your specified limit (higher for buy orders, lower for sell orders).
            /// - There is insufficient volume available to satisfy the full order size.
            case limit
            /// Quote orders get executed at the specified level.
            ///
            /// The level has to be accompanied by a valid quote id (i.e. Lightstreamer price quote identifier).
            ///
            /// A quoteID is the two-way market price that we are making for a given instrument. Because it is two-way, you can 'buy' or 'sell', according to whether you think the price will rise or fall
            /// - note: This type is only available subject to agreement with IG.
            case quote(id: String)
            
            fileprivate var rawValue: String {
                switch self {
                case .market: return "MARKET"
                case .limit: return "LIMIT"
                case .quote(_): return "QUOTE"
                }
            }
        }
        
        /// The order fill strategy.
        public enum Strategy: String, Encodable {
            /// Execute and eliminate.
            case execute = "EXECUTE_AND_ELIMINATE"
            /// Fill or kill.
            case fillOrKill = "FILL_OR_KILL"
        }
    }
    
    /// Indicates the price for a given instrument.
    public struct Boundaries: Encodable {
        /// The limit level at which the user is happy with his/her profits.
        ///
        /// It can be marked as a distance from the buy/sell level, or as an absolute value, or none (in which the position is open).
        public let limit: API.Position.Boundary.Limit?
        /// The stop level at which the user don't want to take more losses.
        ///
        /// It can be marked as a distance from the buy/sell level, or as an absolute value, or none (in which the position is open).
        public let stop: API.Position.Boundary.Stop?
        /// Boolean indicating if a guaranteed stop is required.
        ///
        /// A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
        /// - note: Guaranteed stops come at the price of an increased spread
        public let isStopGuaranteed: Bool
        /// Returns a boolean indicating whether there are no boundaries set.
        public var isEmpty: Bool { return (self.limit == nil) && (self.stop == nil) }
        
        /// Designated initializer to indicate a level/price and one or both of its boundaries.
        public init(limit: API.Position.Boundary.Limit? = nil, stop: (type: API.Position.Boundary.Stop, isGuaranteed: Bool)? = nil) {
            self.limit = limit
            self.stop = stop?.type
            guard let (type, isGuaranteed) = stop else {
                self.isStopGuaranteed = false; return
            }
            
            if case .trailing(_) = type {
                self.isStopGuaranteed = false; return
            }
            
            self.isStopGuaranteed = isGuaranteed
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            if let limit = self.limit {
                switch limit {
                case .distance(let distance): try container.encode(distance, forKey: .limitDistance)
                case .position(let position): try container.encode(position, forKey: .limitLevel)
                }
            }
            
            if let stop = self.stop {
                try container.encode(self.isStopGuaranteed, forKey: .isGuaranteedStop)
                
                switch stop {
                case .position(let position):
                    try container.encode(position, forKey: .stopLevel)
                    try container.encode(false, forKey: .isTrailingStop)
                case .distance(let distance):
                    try container.encode(distance, forKey: .stopDistance)
                    try container.encode(false, forKey: .isTrailingStop)
                case .trailing(distance: let distance, increment: let increment):
                    try container.encode(distance, forKey: .stopDistance)
                    try container.encode(true, forKey: .isTrailingStop)
                    try container.encode(increment, forKey: .trailingStopIncrement)
                }
            } else {
                try container.encode(false, forKey: .isGuaranteedStop)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case limitDistance
            case limitLevel
            case stopDistance
            case stopLevel
            case isTrailingStop = "trailingStop"
            case trailingStopIncrement
            case isGuaranteedStop = "guaranteedStop"
        }
    }
}

// MARK: -

extension API.Response.Position {
    /// Wrapper around a single deal reference.
    fileprivate struct ReferenceWrapper: Decodable {
        // The transient deal reference (for an unconfirmed trade)
        let dealReference: String
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
}
