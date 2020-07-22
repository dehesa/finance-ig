import Combine
import Decimals


extension API.Request.Deals {
    
    // MARK: GET /positions
    
    /// Returns all open positions for the active account.
    ///
    /// A position is a running bet, which may be long (buy) or short (sell).
    /// - returns: *Future* forwarding a list of open positions.
    public func getPositions() -> AnyPublisher<[API.Position],IG.Error> {
        self.api.publisher
            .makeRequest(.get, "positions", version: 2, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(date: true)) { (w: _WrappedPositions, _) in w.positions }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /positions/{dealId}
    
    /// Returns an open position for the active account by deal identifier.
    /// - parameter identifier: Targeted permanent deal reference for an already confirmed trade.
    /// - returns: *Future* forwarding the targeted position.
    public func getPosition(id: IG.Deal.Identifier) -> AnyPublisher<API.Position,IG.Error> {
        self.api.publisher
            .makeRequest(.get, "positions/\(id)", version: 2, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(date: true))
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: POST /positions/otc
    
    /// Creates a new position.
    ///
    /// This endpoint creates a "transient" position (identified by the returned deal reference).
    /// - parameter reference: (default `nil`) A user-defined reference (e.g. `RV3JY2CVMHG1BH`) identifying the submission of the order. If `nil` a reference will be created by the server and return as the result of this enpoint.
    /// - parameter epic: Instrument epic identifer.
    /// - parameter expiry: The date (and sometimes "time") at which a spreadbet or CFD will automatically close against some predefined market value should the bet remain open beyond its last dealing time. Some CFDs do not expire.
    /// - parameter currency: The currency code (3 letters).
    /// - parameter direction: Deal direction (whether buy or sell).
    /// - parameter order: Describes how the user's order must be executed (and at which level).
    /// - parameter strategy: The order fill strategy.
    /// - parameter size: Deal size. Precision shall not be more than 12 decimal places.
    /// - parameter limit: Optional limit level/distance at which the user will like to take profit. It can be marked as a distance from the buy/sell level, or as an absolute value,
    /// - parameter stop: Optional stop at which the user doesn't want to incur more losses. Positions may additional set risk limited stops and trailing stops.
    /// - parameter forceOpen: (default `true`). Enabling force open when creating a new position will enable a second position to be opened on a market. This variable must be `true` if the limit and/or the stop are set.
    /// - returns: The transient deal reference (for an unconfirmed trade). If `reference` was set as an argument, that same value will be returned.
    /// - note: The position is not really open till the server confirms the "transient" position and gives the user a deal identifier.
    ///
    /// Some variables require specific toggles/settings:<br>
    /// - Setting a limit or a stop requires `force` open to be `true`. If not, an error will be thrown.
    /// - If a trailing stop is chosen, the "stop distance" and the "trailing distance" must be the same number.
    public func createPosition(reference: IG.Deal.Reference? = nil, epic: IG.Market.Epic, expiry: IG.Market.Expiry = .none, currency: Currency.Code?, direction: IG.Deal.Direction,
                               order: Self.Position.Order, strategy: Self.Position.FillStrategy, size: Decimal64, limit: IG.Deal.Boundary?, stop: Self.Position.Stop?, forceOpen: Bool = true) -> AnyPublisher<IG.Deal.Reference,IG.Error> {
        self.api.publisher { _ in try _PayloadCreation(reference: reference, epic: epic, expiry: expiry, currency: currency, direction: direction, order: order, strategy: strategy, size: size, limit: limit, stop: stop, forceOpen: forceOpen) }
            .makeRequest(.post, "positions/otc", version: 2, credentials: true, body: { (.json, try JSONEncoder().encode($0)) })
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperReference, _) in w.dealReference }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: PUT /positions/otc/{dealId}
    
    /// Edits an opened position (identified by the given deal identifier).
    ///
    /// This endpoint modifies an openned position. The returned refence is not considered as taken into effect until the server confirms the "transient" position reference and give the user a deal identifier.
    /// - attention: Using this function on a position with a guaranteed stop will transform the stop into a exposed risk stop.
    /// - parameter id: A permanent deal reference for a confirmed trade.
    /// - parameter limitLevel: Passing a value, will set a limit level (replacing the previous one, if any). Setting this argument to `nil` will delete the limit on the position.
    /// - parameter stop: Passing values will set a stop level (replacing the previous one, if any). Setting this argument to `nil` will delete the stop position.
    /// - returns: *Future* forwarding the transient deal reference (for an unconfirmed trade).
    public func updatePosition(id: IG.Deal.Identifier, limitLevel: Decimal64?, stop: Self.Position.StopEdit?) -> AnyPublisher<IG.Deal.Reference,IG.Error> {
        self.api.publisher { _ in try _PayloadUpdate(limit: limitLevel, stop: stop) }
            .makeRequest(.put, "positions/otc/\(id)", version: 2, credentials: true, body: { (.json, try JSONEncoder().encode($0)) })
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperReference, _) in w.dealReference }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }

    
    // MARK: DELETE /positions/otc
    
    /// Closes one or more positions.
    /// - parameter request: A filter to match the positions to be deleted.
    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
    public func closePosition(matchedBy identification: Self.Identification, direction: IG.Deal.Direction, order: API.Request.Deals.Position.Order, strategy: API.Request.Deals.Position.FillStrategy, size: Decimal64) -> AnyPublisher<IG.Deal.Reference,IG.Error> {
        self.api.publisher { _ in try _PayloadDeletion(identification: identification, direction: direction, order: order, strategy: strategy, size: size) }
            .makeRequest(.post, "positions/otc", version: 1, credentials: true, headers: { _ in [._method: API.HTTP.Method.delete.rawValue] }, body: { (.json, try JSONEncoder().encode($0)) })
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperReference, _) in w.dealReference }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

extension API.Request.Deals {
    public enum Position {}
    
    /// Identification mechanism at deletion time.
    public enum Identification {
        /// Permanent deal identifier for a confirmed trade.
        case identifier(IG.Deal.Identifier)
        /// Instrument epic identifier.
        case epic(IG.Market.Epic, expiry: IG.Market.Expiry)
    }
}

extension API.Request.Deals.Position {
    /// Describes how the user's order must be executed.
    public enum Order {
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
        case limit(level: Decimal64)
        /// Quote orders get executed at the specified level.
        ///
        /// The level has to be accompanied by a valid quote id (i.e. Lightstreamer price quote identifier).
        ///
        /// A quoteID is the two-way market price that we are making for a given instrument. Because it is two-way, you can 'buy' or 'sell', according to whether you think the price will rise or fall
        /// - note: This type is only available subject to agreement with IG.
        case quote(id: String, level: Decimal64)
        
        /// Returns the level for the order if it is known.
        var level: Decimal64? {
            switch self {
            case .market: return nil
            case .limit(let level): return level
            case .quote(_, let level): return level
            }
        }
        
        /// The representation understood by the server.
        fileprivate enum _Values {
            static var market: String { "MARKET" }
            static var limit: String { "LIMIT" }
            static var quote: String { "QUOTE" }
        }
    }

    /// The order fill strategy.
    public enum FillStrategy {
        /// Execute and eliminate.
        case execute
        /// Fill or kill.
        case fillOrKill
        
        /// The representation understood by the server.
        fileprivate enum _Values {
            static var execute: String { "EXECUTE_AND_ELIMINATE" }
            static var fillOrKill: String { "FILL_OR_KILL" }
        }
    }

    /// The level/price at which the user doesn't want to incur more lose.
    public enum Stop {
        /// Absolute value of the stop (e.g. 1.653 USD/EUR).
        case level(Decimal64, risk: IG.Deal.Stop.Risk = .exposed)
        /// Relative stop over an undisclosed reference level.
        case distance(Decimal64, risk: IG.Deal.Stop.Risk = .exposed)
        /// A distance from the buy/sell level which will be moved towards the current level in case of a favourable trade.
        /// - attention: Trailing stops are always "risk exposed" (i.e. the stop is not guaranteed).
        /// - parameter distance: The distance from the  market price.
        /// - parameter increment: The stop level increment step in pips.
        case trailing(distance: Decimal64, increment: Decimal64)
    }
    
    /// Available types of stops allowed during position amendment.
    public enum StopEdit {
        /// Absolute value of the stop (e.g. 1.653 USD/EUR).
        case level(Decimal64)
        /// A distance from the buy/sell level which will be moved towards the current level in case of a favourable trade.
        /// - parameter level: The new stop level.
        /// - parameter distance: The distance from the  market price at which point the stop will jump.
        /// - parameter increment: The stop level increment step in pips.
        case trailing(level: Decimal64, distance: Decimal64, increment: Decimal64)
    }
}

private extension API.Request.Deals {
    struct _PayloadCreation: Encodable {
        let reference: IG.Deal.Reference?
        let (epic, expiry): (IG.Market.Epic, IG.Market.Expiry)
        let currency: Currency.Code?
        let direction: IG.Deal.Direction
        let order: API.Request.Deals.Position.Order
        let strategy: API.Request.Deals.Position.FillStrategy
        let size: Decimal64
        let limit: IG.Deal.Boundary?
        let stop: API.Request.Deals.Position.Stop?
        let forceOpen: Bool
        
        /// Designated initializer for Position creation payload.
        /// - throws: `IG.Error` exclusively.
        init(reference: IG.Deal.Reference?, epic: IG.Market.Epic, expiry: IG.Market.Expiry, currency: Currency.Code? = nil, direction: IG.Deal.Direction, order: API.Request.Deals.Position.Order, strategy: API.Request.Deals.Position.FillStrategy, size: Decimal64, limit: IG.Deal.Boundary?, stop: API.Request.Deals.Position.Stop?, forceOpen: Bool) throws {
            self.reference = reference
            (self.epic, self.expiry) = (epic, expiry)
            self.currency = currency
            self.direction = direction
            self.order = order
            self.strategy = strategy
            
            guard size > .zero else { throw IG.Error(.api(.invalidRequest), "Invalid size '\(size)'.", help: "The position size must be a positive greater-than-zero number.") }
            self.size = size
            
            // If a limit or stop is set, then `forceOpen` must be true.
            if limit != nil || stop != nil {
                guard forceOpen else { throw IG.Error(.api(.invalidRequest), "Invalid 'forceOpen' value for the given limit or stop.", help: "The position must set 'forceOpen' to true if a limit or stop is set.") }
            }
            self.forceOpen = forceOpen
            
            // If a limit is set, validate it.
            if let limit = limit {
                switch (limit, order.level, direction) {
                case (.distance(let distance), _, _):
                    guard distance > 0 else { throw IG.Error(.api(.invalidRequest), "Invalid limit distance '\(distance)'.", help: "The limit distance must be a positive greater-than-zero number.") }
                case (.level(let limitLevel), let level?, .buy):
                    guard limitLevel > level else { throw IG.Error(.api(.invalidRequest), "Invalid limit level.", help: "The limit level must be above the order level for 'buy' deals.") }
                case (.level(let limitLevel), let level?, .sell):
                    guard limitLevel < level else { throw IG.Error(.api(.invalidRequest), "Invalid limit level.", help: "The limit level must be below the order level for 'sell' deals.") }
                default: break
                }
                self.limit = limit
            } else { self.limit = nil }
            
            // If a stop is set, validate it.
            if let stop = stop {
                switch (stop, order.level, direction) {
                case (.level(let stopLevel, _), let level?, .buy):
                    guard stopLevel < level else { throw IG.Error(.api(.invalidRequest), "Invalid stop level.", help: "The stop level must be below the order level for 'buy' deals.") }
                case (.level(let stopLevel, _), let level?, .sell):
                    guard stopLevel > level else { throw IG.Error(.api(.invalidRequest), "Invalid stop level.", help: "The stop level must be above the order level for 'sell' deals.") }
                case (.distance(let distance, _), _, _):
                    guard distance > 0 else { throw IG.Error(.api(.invalidRequest), "Invalid stop distance.", help: "The stop distance must be a positive greater-than-zero number.") }
                case (.trailing(let distance, let increment), _, _):
                    guard distance > 0 && increment > 0 else { throw IG.Error(.api(.invalidRequest), "Invalid trailing stop.", help: "The trailing stop distance and increment must be positive greater-than-zero numbers.") }
                default: break
                }
                self.stop = stop
            } else { self.stop = nil }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _Keys.self)
            try container.encodeIfPresent(self.reference, forKey: .reference)
            try container.encode(self.epic, forKey: .epic)
            try container.encode(self.expiry, forKey: .expiry)
            try container.encodeIfPresent(self.currency, forKey: .currency)
            try container.encode(self.direction, forKey: .direction)
            
            switch self.order {
            case .market:
                try container.encode(API.Request.Deals.Position.Order._Values.market, forKey: .order)
            case .limit(level: let level):
                try container.encode(API.Request.Deals.Position.Order._Values.limit, forKey: .order)
                try container.encode(level, forKey: .level)
            case .quote(id: let quoteId, level: let level):
                try container.encode(API.Request.Deals.Position.Order._Values.quote, forKey: .order)
                try container.encode(level, forKey: .level)
                try container.encode(quoteId, forKey: .quoteId)
            }
            
            switch self.strategy {
            case .execute: try container.encode(API.Request.Deals.Position.FillStrategy._Values.execute, forKey: .fillStrategy)
            case .fillOrKill: try container.encode(API.Request.Deals.Position.FillStrategy._Values.fillOrKill, forKey: .fillStrategy)
            }
            try container.encode(self.size, forKey: .size)
            
            if let limit = self.limit {
                switch limit {
                case .level(let l): try container.encode(l, forKey: .limitLevel)
                case .distance(let d): try container.encode(d, forKey: .limitDistance)
                }
            }
            
            if let stop = self.stop {
                switch stop {
                case .level(let l, let r):
                    try container.encode(r == .limited, forKey: .isStopGuaranteed)
                    try container.encode(false, forKey: .isStopTrailing)
                    try container.encode(l, forKey: .stopLevel)
                case .distance(let d, let r):
                    try container.encode(r == .limited, forKey: .isStopGuaranteed)
                    try container.encode(false, forKey: .isStopTrailing)
                    try container.encode(d, forKey: .stopDistance)
                case .trailing(let d, let i):
                    try container.encode(false, forKey: .isStopGuaranteed)
                    try container.encode(true, forKey: .isStopTrailing)
                    try container.encode(d, forKey: .stopDistance)
                    try container.encode(i, forKey: .stopTrailingIncrement)
                }
            } else {
                try container.encode(false, forKey: .isStopGuaranteed)
            }
            
            try container.encode(self.forceOpen, forKey: .forceOpen)
        }
        
        private enum _Keys: String, CodingKey {
            case epic, expiry
            case currency = "currencyCode"
            case direction
            case order = "orderType", level, quoteId
            case fillStrategy = "timeInForce"
            case size
            case limitLevel, limitDistance
            case stopLevel, stopDistance
            case isStopGuaranteed = "guaranteedStop"
            case isStopTrailing = "trailingStop"
            case stopTrailingIncrement = "trailingStopIncrement"
            case forceOpen
            case reference = "dealReference"
        }
    }
}

private extension API.Request.Deals {
    struct _PayloadUpdate: Encodable {
        let limitLevel: Decimal64?
        let stop: API.Request.Deals.Position.StopEdit?
        
        init(limit: Decimal64?, stop: API.Request.Deals.Position.StopEdit?) throws {
            if case .trailing(_, let distance, let increment) = stop {
                guard distance > 0, increment > 0 else {
                    throw IG.Error(.api(.invalidRequest), "Invalid stop for position amendment.", help: "The trailing stop distance and increment must be positive greater-than-zero numbers.", info: ["Trailing stop distance": distance, "Trailing stop increment": increment])
                }
            }
            self.limitLevel = limit
            self.stop = stop
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _Keys.self)
            
            switch self.limitLevel {
            case .none:  try container.encodeNil(forKey: .limitLevel)
            case let l?: try container.encodeIfPresent(l, forKey: .limitLevel)
            }
            
            switch self.stop {
            case .none:
                try container.encodeNil(forKey: .stopLevel)
                try container.encode(false, forKey: .isTrailingStop)
                try container.encodeNil(forKey: .stopTrailingDistance)
                try container.encodeNil(forKey: .stopTrailingIncrement)
            case .level(let l):
                try container.encode(l, forKey: .stopLevel)
                try container.encode(false, forKey: .isTrailingStop)
                try container.encodeNil(forKey: .stopTrailingDistance)
                try container.encodeNil(forKey: .stopTrailingIncrement)
            case .trailing(let l, let d, let i):
                try container.encode(l, forKey: .stopLevel)
                try container.encode(true, forKey: .isTrailingStop)
                try container.encode(d, forKey: .stopTrailingDistance)
                try container.encode(i, forKey: .stopTrailingIncrement)
            }
        }
        
        private enum _Keys: String, CodingKey {
            case limitLevel, stopLevel
            case isTrailingStop = "trailingStop"
            case stopTrailingDistance = "trailingStopDistance"
            case stopTrailingIncrement = "trailingStopIncrement"
        }
    }
}

private extension API.Request.Deals {
    struct _PayloadDeletion: Encodable {
        let identification: API.Request.Deals.Identification
        let direction: IG.Deal.Direction
        let order: API.Request.Deals.Position.Order
        let strategy: API.Request.Deals.Position.FillStrategy
        let size: Decimal64
        
        init(identification: API.Request.Deals.Identification, direction: IG.Deal.Direction, order: API.Request.Deals.Position.Order, strategy: API.Request.Deals.Position.FillStrategy, size: Decimal64) throws {
            guard size > .zero else { throw IG.Error(.api(.invalidRequest), "Invalid size '\(size)'.", help: "The position size must be a positive greater-than-zero number.") }
            self.identification = identification
            self.direction = direction
            self.order = order
            self.strategy = strategy
            self.size = size
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _Keys.self)
            switch self.identification {
            case .identifier(let identifier):
                try container.encode(identifier, forKey: .identifier)
            case .epic(let epic, let expiry):
                try container.encode(epic, forKey: .epic)
                try container.encode(expiry, forKey: .expiry)
            }
            
            try container.encode(self.direction, forKey: .direction)
            
            switch self.order {
            case .market:
                try container.encode(API.Request.Deals.Position.Order._Values.market, forKey: .order)
            case .limit(level: let level):
                try container.encode(API.Request.Deals.Position.Order._Values.limit, forKey: .order)
                try container.encode(level, forKey: .level)
            case .quote(id: let quoteId, level: let level):
                try container.encode(API.Request.Deals.Position.Order._Values.quote, forKey: .order)
                try container.encode(level, forKey: .level)
                try container.encode(quoteId, forKey: .quoteId)
            }
            
            switch self.strategy {
            case .execute: try container.encode(API.Request.Deals.Position.FillStrategy._Values.execute, forKey: .fillStrategy)
            case .fillOrKill: try container.encode(API.Request.Deals.Position.FillStrategy._Values.fillOrKill, forKey: .fillStrategy)
            }
            
            try container.encode(self.size, forKey: .size)
        }
        
        private enum _Keys: String, CodingKey {
            case identifier = "dealId"
            case epic, expiry
            case direction
            case order = "orderType", level, quoteId
            case fillStrategy = "timeInForce"
            case size
        }
    }
}

// MARK: Response Entities

private extension API.Request.Deals {
    struct _WrappedPositions: Decodable {
        let positions: [API.Position]
    }

    struct _WrapperReference: Decodable {
        let dealReference: IG.Deal.Reference
    }
}
