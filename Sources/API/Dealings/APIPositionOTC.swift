import ReactiveSwift
import Foundation

extension API.Request.Positions {
    
    // MARK: POST /positions/otc
    
    /// Creates a new position.
    ///
    /// This endpoint creates a "transient" position (identified by the returned deal reference).
    /// The position is not really open till the server confirms the "transient" position and gives the user a deal identifier.
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
    /// - note: Some variables require specific toggles/settings:<br>
    ///         - All `Decimal` values must be positive numbers and greater than zero.
    ///         - Setting a limit or a stop requires `force` open to be `true`. If not, an error will be returned.
    ///         - If a trailing stop is chosen, the trailing behavior must be set.
    ///         - If a trailing stop is chosen, the "stop distance" and the "trailing distance" must be the same number.
    public func create(epic: Epic, expiry: API.Instrument.Expiry = .none, currency: Currency.Code, direction: API.Deal.Direction,
                       order: API.Position.Order, strategy: API.Position.Order.Strategy,
                       size: Decimal, limit: API.Deal.Limit?, stop: API.Deal.Stop?,
                       forceOpen: Bool = true, reference: API.Deal.Reference? = nil) -> SignalProducer<API.Deal.Reference,API.Error> {
        return SignalProducer(api: self.api) { (_) -> Self.PayloadCreation in
                return try .init(epic: epic, expiry: expiry, currency: currency, direction: direction, order: order, strategy: strategy, size: size, limit: limit, stop: stop, forceOpen: forceOpen, reference: reference)
            }.request(.post, "positions/otc", version: 2, credentials: true, body: { (_, payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperReference) in w.dealReference }
    }
    
    // MARK: PUT /positions/otc/{dealId}
    
    /// Edits an opened position (identified by the given deal identifier).
    ///
    /// This endpoint modifies an openned position. The returned refence is not considered as taken into effect until the server confirms the "transient" position reference and give the user a deal identifier.
    /// - parameter identifier: A permanent deal reference for a confirmed trade.
    /// - parameter limitLevel: Passing a value, will set a limit level (replacing the previous one, if any). Setting this argument to `nil` will delete the limit on the position.
    /// - parameter stop: Passing a value will set a stop level (replacing the previous one, if any). Setting this argument to `nil` will delete the stop position.
    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
    /// - note: Using this function on a position with a guaranteed stop will transform the stop into a exposed risk stop.
    public func update(identifier: API.Deal.Identifier, limitLevel: Decimal?, stop: (level: Decimal, trailing: API.Deal.Stop.Trailing)?) -> SignalProducer<API.Deal.Reference,API.Error> {
        return SignalProducer(api: self.api)  { (_) -> Self.PayloadUpdate in
                return try .init(limit: limitLevel, stop: stop)
            }.request(.put, "positions/otc/\(identifier.rawValue)", version: 2, credentials: true, body: { (_, payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperReference) in w.dealReference }
    }

    
    // MARK: DELETE /positions/otc
    
    /// Closes one or more positions.
    /// - parameter request: A filter to match the positions to be deleted.
    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
    public func delete(matchedBy identification: Self.Identification, direction: API.Deal.Direction,
                       order: API.Position.Order, strategy: API.Position.Order.Strategy, size: Decimal) -> SignalProducer<API.Deal.Reference,API.Error> {
        return SignalProducer(api: self.api) { (_) -> Self.PayloadDeletion in
                return try .init(identification: identification, direction: direction, order: order, strategy: strategy, size: size)
            }.request(.post, "positions/otc", version: 1, credentials: true, headers: { (_,_) in
                [._method: API.HTTP.Method.delete.rawValue]
            }, body: { (_, payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperReference) in w.dealReference }
    }
}

// MARK: - Supporting Entities

// MARK: Request Entities

extension API.Request.Positions {
    private struct PayloadCreation: Encodable {
        let epic: Epic
        let expiry: API.Instrument.Expiry
        let currency: Currency.Code
        let direction: API.Deal.Direction
        let order: API.Position.Order
        let strategy: API.Position.Order.Strategy
        let size: Decimal
        let limit: API.Deal.Limit?
        let stop: API.Deal.Stop?
        let forceOpen: Bool
        let reference: API.Deal.Reference?
        
        init(epic: Epic, expiry: API.Instrument.Expiry, currency: Currency.Code, direction: API.Deal.Direction, order: API.Position.Order, strategy: API.Position.Order.Strategy, size: Decimal, limit: API.Deal.Limit?, stop: API.Deal.Stop?, forceOpen: Bool, reference: API.Deal.Reference?) throws {
            self.epic = epic
            self.expiry = expiry
            self.currency = currency
            self.direction = direction
            self.order = order
            self.strategy = strategy
            // Check the size for negative numbers or zero.
            guard size.isNormal, case .plus = size.sign else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "The size value \"\(size)\" must be a valid number and greater than zero.")
            }
            // Check the limit for forceOpen agreement and for level/distance validity.
            if let limit = limit {
                guard forceOpen else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "A position must set \"force open\" to true if a limit is set.")
                }
                
                guard limit.isValid(with: order.level.map { ($0, direction) }) else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The given limit is invalid. Limit: \(limit)")
                }
            }
            // Check the stop for forceOpen agreement, for level/distance validity, and for trailing behavior.
            if let stop = stop {
                guard forceOpen else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "A position must set \"force open\" to true if a stop is set.")
                }
                
                guard stop.isValid(with: order.level.map { ($0, direction) }) else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The given stop is invalid. Stop: \(stop)")
                }
                
                if case .dynamic(let settings) = stop.trailing {
                    guard case .some(let trailing) = settings else {
                        throw API.Error.invalidRequest(underlyingError: nil, message: "If a trailing stop is chosen, the trailing distance and increment must be specified.")
                    }
                    
                    guard case .distance(let stopDistance) = stop.type else {
                        throw API.Error.invalidRequest(underlyingError: nil, message: "If a trailing stop is chosen, only the type \".distance\" is allowed as a stop level.")
                    }
                    
                    guard trailing.distance.isEqual(to: stopDistance) else {
                        throw API.Error.invalidRequest(underlyingError: nil, message: "If a trailing stop is chosen, the stop distance and the trailing distance must match on position creation time.")
                    }
                    
                    guard trailing.increment.isNormal, case .plus = trailing.increment.sign else {
                        throw API.Error.invalidRequest(underlyingError: nil, message: "The trailing increment provided must be a positive number and greater than zero.")
                    }
                }
            }
            self.size = size
            self.limit = limit
            self.stop = stop
            self.forceOpen = forceOpen
            self.reference = reference
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Self.CodingKeys.self)
            try container.encode(self.epic, forKey: .epic)
            try container.encode(self.expiry, forKey: .expiry)
            try container.encode(self.currency, forKey: .currency)
            try container.encode(self.direction, forKey: .direction)
            try container.encode(self.order.rawValue, forKey: .order)
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
            
            switch limit {
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
                case .dynamic(let behavior): try container.encode(true,  forKey: .isStopTrailing)
                    guard let behavior = behavior else {
                        var codingPaths = container.codingPath
                        codingPaths.append(Self.CodingKeys.isStopTrailing)
                        throw EncodingError.invalidValue(stop.trailing, EncodingError.Context(codingPath: codingPaths, debugDescription: "The stop trailing behavior was not found."))
                    }
                    //try container.encode(behavior.distance, forKey: .stopDistance)
                    try container.encode(behavior.increment, forKey: .stopTrailingDistance)
                }
            } else {
                try container.encode(false, forKey: .isStopGuaranteed)
            }
            
            try container.encode(self.forceOpen, forKey: .forceOpen)
            try container.encodeIfPresent(self.reference, forKey: .reference)
        }
        
        private enum CodingKeys: String, CodingKey {
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
            case stopTrailingDistance = "trailingStopIncrement"
            case forceOpen
            case reference = "dealReference"
        }
    }
}

extension API.Request.Positions {
    private struct PayloadUpdate: Encodable {
        let limit: Decimal?
        let stop: (level: Decimal, trailing: API.Deal.Stop.Trailing)?
        
        init(limit: Decimal?, stop: (level: Decimal, trailing: API.Deal.Stop.Trailing)?) throws {
            if let stop = stop, case .dynamic(let behavior) = stop.trailing {
                guard case .some(let behavior) = behavior else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "If a trailing stop is chosen, the trailing distance and increment must be specified.")
                }
                
                guard behavior.distance.isNormal, case .plus = behavior.distance.sign else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The trailing disance provided must be a positive number and greater than zero.")
                }
                
                guard behavior.increment.isNormal, case .plus = behavior.increment.sign else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The trailing increment provided must be a positive number and greater than zero.")
                }
            }
            
            self.limit = limit
            self.stop = stop
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Self.CodingKeys.self)
            
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
                        codingPaths.append(Self.CodingKeys.isTrailingStop)
                        throw EncodingError.invalidValue(stop.trailing, EncodingError.Context(codingPath: codingPaths, debugDescription: "The stop trailing behavior was not found."))
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
        
        private enum CodingKeys: String, CodingKey {
            case limitLevel, stopLevel
            case isTrailingStop = "trailingStop"
            case stopTrailingDistance = "trailingStopDistance"
            case stopTrailingIncrement = "trailingStopIncrement"
        }
    }
}

extension API.Request.Positions {
    /// Identification mechanism at deletion time.
    public enum Identification {
        /// Permanent deal identifier for a confirmed trade.
        case identifier(API.Deal.Identifier)
        /// Instrument epic identifier.
        case epic(Epic, expiry: API.Instrument.Expiry)
    }
}

extension API.Request.Positions {
    private struct PayloadDeletion: Encodable {
        let identification: API.Request.Positions.Identification
        let direction: API.Deal.Direction
        let order: API.Position.Order
        let strategy: API.Position.Order.Strategy
        let size: Decimal
        
        init(identification: API.Request.Positions.Identification, direction: API.Deal.Direction, order: API.Position.Order, strategy: API.Position.Order.Strategy, size: Decimal) throws {
            // Check the size for negative numbers or zero.
            guard size.isNormal, case .plus = size.sign else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "The size value \"\(size)\" must be a valid number and greater than zero.")
            }
            
            self.identification = identification
            self.direction = direction
            self.order = order
            self.strategy = strategy
            self.size = size
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Self.CodingKeys.self)
            switch self.identification {
            case .identifier(let identifier):
                try container.encode(identifier, forKey: .identifier)
            case .epic(let epic, let expiry):
                try container.encode(epic, forKey: .epic)
                try container.encode(expiry, forKey: .expiry)
            }
            
            try container.encode(self.direction, forKey: .direction)
            try container.encode(self.order.rawValue, forKey: .order)
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
        
        private enum CodingKeys: String, CodingKey {
            case identifier = "dealId"
            case epic, expiry
            case direction
            case order = "orderType", level, quoteId
            case fillStrategy = "timeInForce"
            case size
        }
    }
}

extension API.Position.Order {
    /// The representation understood by the server.
    fileprivate var rawValue: String {
        switch self {
        case .market: return "MARKET"
        case .limit: return "LIMIT"
        case .quote(_): return "QUOTE"
        }
    }
}

// MARK: Response Entities

extension API.Request.Positions {
    private struct WrapperReference: Decodable {
        let dealReference: API.Deal.Reference
    }
}
