import Combine
import Foundation

extension IG.API.Request.Positions {
    
    // MARK: POST /positions/otc
    
    /// Creates a new position.
    ///
    /// This endpoint creates a "transient" position (identified by the returned deal reference).
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
    /// - parameter reference: (default `nil`). A user-defined reference (e.g. `RV3JZ2CWMHG1BK`) identifying the submission of the order. If `nil` a reference will be created by the server and return as the result of this enpoint.
    /// - returns: The transient deal reference (for an unconfirmed trade). If `reference` was set as an argument, that same value will be returned.
    /// - note: The position is not really open till the server confirms the "transient" position and gives the user a deal identifier.
    ///
    /// Some variables require specific toggles/settings:<br>
    /// - All `Decimal` values must be positive numbers and greater than zero.
    /// - Setting a limit or a stop requires `force` open to be `true`. If not, an error will be returned.
    /// - If a trailing stop is chosen, the trailing behavior must be set.
    /// - If a trailing stop is chosen, the "stop distance" and the "trailing distance" must be the same number.
    public func create(epic: IG.Market.Epic,
                       expiry: IG.Market.Expiry = .none,
                       currency: IG.Currency.Code,
                       direction: IG.Deal.Direction,
                       order: IG.API.Position.Order,
                       strategy: IG.API.Position.Order.Strategy,
                       size: Decimal, limit: IG.Deal.Limit?,
                       stop: IG.Deal.Stop?,
                       forceOpen: Bool = true,
                       reference: IG.Deal.Reference? = nil) -> AnyPublisher<IG.Deal.Reference,IG.API.Error> {
        self.api.publisher { _ in
                try _PayloadCreation(epic: epic, expiry: expiry, currency: currency, direction: direction, order: order, strategy: strategy, size: size, limit: limit, stop: stop, forceOpen: forceOpen, reference: reference)
            }.makeRequest(.post, "positions/otc", version: 2, credentials: true, body: {
                (.json, try JSONEncoder().encode($0))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperReference, _) in w.dealReference }
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK: PUT /positions/otc/{dealId}
    
    /// Edits an opened position (identified by the given deal identifier).
    ///
    /// This endpoint modifies an openned position. The returned refence is not considered as taken into effect until the server confirms the "transient" position reference and give the user a deal identifier.
    /// - parameter identifier: A permanent deal reference for a confirmed trade.
    /// - parameter limitLevel: Passing a value, will set a limit level (replacing the previous one, if any). Setting this argument to `nil` will delete the limit on the position.
    /// - parameter stop: Passing values will set a stop level (replacing the previous one, if any). Setting this argument to `nil` will delete the stop position.
    /// - returns: *Future* forwarding the transient deal reference (for an unconfirmed trade).
    /// - note: Using this function on a position with a guaranteed stop will transform the stop into a exposed risk stop.
    public func update(identifier: IG.Deal.Identifier,
                       limitLevel: Decimal?,
                       stop: (level: Decimal, trailing: IG.Deal.Stop.Trailing)?) -> AnyPublisher<IG.Deal.Reference,IG.API.Error> {
        self.api.publisher { _ in
                try _PayloadUpdate(limit: limitLevel, stop: stop)
            }.makeRequest(.put, "positions/otc/\(identifier.rawValue)", version: 2, credentials: true, body: {
                (.json, try JSONEncoder().encode($0))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperReference, _) in w.dealReference }
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }

    
    // MARK: DELETE /positions/otc
    
    /// Closes one or more positions.
    /// - parameter request: A filter to match the positions to be deleted.
    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
    public func delete(matchedBy identification: Self.Identification,
                       direction: IG.Deal.Direction,
                       order: IG.API.Position.Order,
                       strategy: IG.API.Position.Order.Strategy,
                       size: Decimal) -> AnyPublisher<IG.Deal.Reference,IG.API.Error> {
        self.api.publisher { _ in
                try _PayloadDeletion(identification: identification, direction: direction, order: order, strategy: strategy, size: size)
            }.makeRequest(.post, "positions/otc", version: 1, credentials: true, headers: { _ in [._method: IG.API.HTTP.Method.delete.rawValue] }, body: {
                (.json, try JSONEncoder().encode($0))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperReference, _) in w.dealReference }
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.API.Request.Positions {
    private struct _PayloadCreation: Encodable {
        let epic: IG.Market.Epic
        let expiry: IG.Market.Expiry
        let currency: IG.Currency.Code
        let direction: IG.Deal.Direction
        let order: IG.API.Position.Order
        let strategy: IG.API.Position.Order.Strategy
        let size: Decimal
        let limit: IG.Deal.Limit?
        let stop: IG.Deal.Stop?
        let forceOpen: Bool
        let reference: IG.Deal.Reference?
        
        /// Designated initializer for Position creation payload.
        /// - throws: `IG.API.Error` exclusively.
        init(epic: IG.Market.Epic, expiry: IG.Market.Expiry, currency: IG.Currency.Code, direction: IG.Deal.Direction, order: IG.API.Position.Order, strategy: IG.API.Position.Order.Strategy, size: Decimal, limit: IG.Deal.Limit?, stop: IG.Deal.Stop?, forceOpen: Bool, reference: IG.Deal.Reference?) throws {
            self.epic = epic
            self.expiry = expiry
            self.currency = currency
            self.direction = direction
            self.order = order
            self.strategy = strategy
            self.size = try {
                guard size.isNormal, case .plus = size.sign else {
                    var error: IG.API.Error = .invalidRequest("The position size number is invalid", suggestion: "The position size must be a positive valid number greater than zero")
                    error.context.append(("Position size", size))
                    throw error
                }
                return size
            }()
            
            typealias E = IG.API.Error
            // Check for "forceOpen" agreement: if a limit or stop is set, then force open must be true
            let forceOpenValidation: (Bool) throws -> Void = {
                guard $0 else {
                    throw E.invalidRequest("The 'forceOpen' value is invalid for the given limit or stop", suggestion: "A position must set 'forceOpen' to true if a limit or stop is set")
                }
            }
            /// Check for limit validation.
            let limitValidation: (IG.Deal.Direction, Decimal, IG.Deal.Limit) throws -> Void = { (direction, base, limit) in
                guard limit.isValid(on: direction, from: base) else {
                    throw E.invalidRequest("The given limit is invalid", suggestion: .validLimit).set { $0.context.append(("Position limit", limit)) }
                }
            }
            /// Check for stop validation.
            let stopValidation: (IG.Deal.Direction, Decimal, IG.Deal.Stop) throws -> Void = { (direction, base, stop) in
                guard stop.isValid(on: direction, from: base) else {
                    throw E.invalidRequest("The given stop is invalid", suggestion: .validStop).set { $0.context.append(("Position stop", stop)) }
                }
            }
            /// Check for trailing validation.
            let trailingValidation: (IG.Deal.Stop) throws -> Void = { (stop) in
                if case .dynamic(let settings) = stop.trailing {
                    guard case .some(let trailing) = settings else {
                        throw E.invalidRequest(.invalidTrailingStop, suggestion: "If a trailing stop is chosen, the trailing distance and increment must be specified").set { $0.context.append(("Position stop", stop)) }
                    }
                    
                    guard case .distance(let stopDistance) = stop.type else {
                        throw E.invalidRequest(.invalidTrailingStop, suggestion: "If a trailing stop is chosen, only the stop type '.distance' is allowed as a stop level").set { $0.context.append(("Position stop", stop)) }
                    }
                    
                    guard trailing.distance.isEqual(to: stopDistance) else {
                        throw E.invalidRequest(.invalidTrailingStop, suggestion: "If a trailing stop is chosen, the stop distance and the trailing distance must match on position creation time").set { $0.context.append(("Position stop", stop)) }
                    }
                    
                    guard trailing.increment.isNormal, case .plus = trailing.increment.sign else {
                        throw E.invalidRequest(.invalidTrailingStop, suggestion: "The trailing increment provided must be a positive number and greater than zero").set { $0.context.append(("Position stop", stop)) }
                    }
                }
            }
            
            switch (limit, stop) {
            case (.none, .none): break
            case (let l?, .none):
                try forceOpenValidation(forceOpen)
                try order.level.map { try limitValidation(direction, $0, l) }
            case (.none, let s?):
                try forceOpenValidation(forceOpen)
                try order.level.map { try stopValidation(direction, $0, s) }
                try trailingValidation(s)
            case (let l?, let s?):
                try forceOpenValidation(forceOpen)
                if let level = order.level {
                    try limitValidation(direction, level, l)
                    try stopValidation(direction, level, s)
                } else if case .position(let limitLevel) = l.type, case .position(let stopLevel) = s.type {
                    try limitValidation(direction, stopLevel, l)
                    try stopValidation(direction, limitLevel, s)
                }
                try trailingValidation(s)
            }
            
            self.limit = limit
            self.stop = stop
            self.forceOpen = forceOpen
            self.reference = reference
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _CodingKeys.self)
            try container.encode(self.epic, forKey: .epic)
            try container.encode(self.expiry, forKey: .expiry)
            try container.encode(self.currency, forKey: .currency)
            try container.encode(self.direction, forKey: .direction)
            try container.encode(self.order._rawValue, forKey: .order)
            switch order {
            case .market: break
            case .limit(level: let level):
                try container.encode(level, forKey: .level)
            case .quote(id: let quoteId, level: let level):
                try container.encode(level, forKey: .level)
                try container.encode(quoteId, forKey: .quoteId)
            }
            try container.encode(self.strategy, forKey: .fillStrategy)
            try container.encode(self.size, forKey: .size)
            
            switch limit?.type {
            case .none: break
            case .position(let level): try container.encode(level, forKey: .limitLevel)
            case .distance(let dista): try container.encode(dista, forKey: .limitDistance)
            }
            
            if let stop = self.stop {
                switch stop.type {
                case .position(let level): try container.encode(level, forKey: .stopLevel)
                case .distance(let dista): try container.encode(dista, forKey: .stopDistance)
                }
                
                switch stop.risk {
                case .exposed: try container.encode(false, forKey: .isStopGuaranteed)
                case .limited: try container.encode(true, forKey: .isStopGuaranteed)
                }
                
                switch stop.trailing {
                case .static:                try container.encode(false, forKey: .isStopTrailing)
                case .dynamic(let settings): try container.encode(true,  forKey: .isStopTrailing)
                    guard let behavior = settings else {
                        var codingPaths = container.codingPath
                        codingPaths.append(_CodingKeys.isStopTrailing)
                        throw EncodingError.invalidValue(stop.trailing, EncodingError.Context(codingPath: codingPaths, debugDescription: "The stop trailing behavior was not found"))
                    }
                    try container.encode(behavior.increment, forKey: .stopTrailingIncrement)
                }
            } else {
                try container.encode(false, forKey: .isStopGuaranteed)
            }
            
            try container.encode(self.forceOpen, forKey: .forceOpen)
            try container.encodeIfPresent(self.reference, forKey: .reference)
        }
        
        private enum _CodingKeys: String, CodingKey {
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

extension IG.API.Request.Positions {
    private struct _PayloadUpdate: Encodable {
        let limit: Decimal?
        let stop: (level: Decimal, trailing: IG.Deal.Stop.Trailing)?
        
        init(limit: Decimal?, stop: (level: Decimal, trailing: IG.Deal.Stop.Trailing)?) throws {
            if let stop = stop, case .dynamic(let settings) = stop.trailing {
                guard case .some(let settings) = settings else {
                    var error: IG.API.Error = .invalidRequest(.invalidTrailingStop, suggestion: "If a trailing stop is chosen, the trailing distance and increment must be specified")
                    error.context.append(("Position stop level", stop.level))
                    error.context.append(("Position stop trailing", stop.trailing))
                    throw error
                }
                
                
                guard IG.Deal.Stop.Trailing.Settings.isValid(settings.distance) else {
                    var error: IG.API.Error = .invalidRequest(.invalidTrailingStop, suggestion: "The trailing disance provided must be a positive number and greater than zero")
                    error.context.append(("Position stop level", stop.level))
                    error.context.append(("Position stop trailing", stop.trailing))
                    throw error
                }
                
                guard IG.Deal.Stop.Trailing.Settings.isValid(settings.increment) else {
                    var error: IG.API.Error = .invalidRequest(.invalidTrailingStop, suggestion: "The trailing increment provided must be a positive number and greater than zero")
                    error.context.append(("Position stop level", stop.level))
                    error.context.append(("Position stop trailing", stop.trailing))
                    throw error
                }
            }
            
            self.limit = limit
            self.stop = stop
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _CodingKeys.self)
            
            if let limit = self.limit {
                try container.encodeIfPresent(limit, forKey: .limitLevel)
            } else {
                try container.encodeNil(forKey: .limitLevel)
            }
            
            if let stop = self.stop {
                try container.encode(stop.level, forKey: .stopLevel)
                switch stop.trailing {
                case .static:
                    try container.encode(false, forKey: .isTrailingStop)
                    try container.encodeNil(forKey: .stopTrailingDistance)
                    try container.encodeNil(forKey: .stopTrailingIncrement)
                case .dynamic(let behavior):
                    guard let behavior = behavior else {
                        var codingPaths = container.codingPath
                        codingPaths.append(_CodingKeys.isTrailingStop)
                        throw EncodingError.invalidValue(stop.trailing, EncodingError.Context(codingPath: codingPaths, debugDescription: "The stop trailing behavior was not found"))
                    }
                    try container.encode(true, forKey: .isTrailingStop)
                    try container.encode(behavior.distance, forKey: .stopTrailingDistance)
                    try container.encode(behavior.increment, forKey: .stopTrailingIncrement)
                }
            } else {
                try container.encodeNil(forKey: .stopLevel)
                try container.encode(false, forKey: .isTrailingStop)
                try container.encodeNil(forKey: .stopTrailingDistance)
                try container.encodeNil(forKey: .stopTrailingIncrement)
            }
        }
        
        private enum _CodingKeys: String, CodingKey {
            case limitLevel, stopLevel
            case isTrailingStop = "trailingStop"
            case stopTrailingDistance = "trailingStopDistance"
            case stopTrailingIncrement = "trailingStopIncrement"
        }
    }
}

extension IG.API.Request.Positions {
    /// Identification mechanism at deletion time.
    public enum Identification {
        /// Permanent deal identifier for a confirmed trade.
        case identifier(IG.Deal.Identifier)
        /// Instrument epic identifier.
        case epic(IG.Market.Epic, expiry: IG.Market.Expiry)
    }
}

extension IG.API.Request.Positions {
    private struct _PayloadDeletion: Encodable {
        let identification: IG.API.Request.Positions.Identification
        let direction: IG.Deal.Direction
        let order: IG.API.Position.Order
        let strategy: IG.API.Position.Order.Strategy
        let size: Decimal
        
        init(identification: IG.API.Request.Positions.Identification, direction: IG.Deal.Direction, order: IG.API.Position.Order, strategy: IG.API.Position.Order.Strategy, size: Decimal) throws {
            // Check the size for negative numbers or zero.
            guard size.isNormal, case .plus = size.sign else {
                var error: IG.API.Error = .invalidRequest("The position size number is invalid", suggestion: "The position size must be a positive valid number greater than zero")
                error.context.append(("Position size", size))
                throw error
            }
            
            self.identification = identification
            self.direction = direction
            self.order = order
            self.strategy = strategy
            self.size = size
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _CodingKeys.self)
            switch self.identification {
            case .identifier(let identifier):
                try container.encode(identifier, forKey: .identifier)
            case .epic(let epic, let expiry):
                try container.encode(epic, forKey: .epic)
                try container.encode(expiry, forKey: .expiry)
            }
            
            try container.encode(self.direction, forKey: .direction)
            try container.encode(self.order._rawValue, forKey: .order)
            switch order {
            case .limit(level: let level):
                try container.encode(level, forKey: .level)
            case .market:
                break
            case .quote(id: let quoteId, level: let level):
                try container.encode(quoteId, forKey: .quoteId)
                try container.encode(level, forKey: .level)
            }
            
            try container.encode(self.strategy, forKey: .fillStrategy)
            try container.encode(self.size, forKey: .size)
        }
        
        private enum _CodingKeys: String, CodingKey {
            case identifier = "dealId"
            case epic, expiry
            case direction
            case order = "orderType", level, quoteId
            case fillStrategy = "timeInForce"
            case size
        }
    }
}

fileprivate extension IG.API.Position.Order {
    /// The representation understood by the server.
    var _rawValue: String {
        switch self {
        case .market: return "MARKET"
        case .limit: return "LIMIT"
        case .quote: return "QUOTE"
        }
    }
}

private extension IG.API.Request.Positions {
    struct _WrapperReference: Decodable {
        let dealReference: IG.Deal.Reference
    }
}
