import ReactiveSwift
import Foundation

extension API.Request.WorkingOrders {
    
    // MARK: POST /workingorders/otc
    
    /// Creates an OTC working order.
    /// - parameter epic: Instrument epic identifer.
    /// - parameter expiry: The date (and sometimes "time") at which a spreadbet or CFD will automatically close against some predefined market value should the bet remain open beyond its last dealing time. Some CFDs do not expire.
    /// - parameter currency: The currency code (3 letters).
    /// - parameter direction: Deal direction (whether buy or sell).
    /// - parameter type: The working order type.
    /// - parameter size: Deal size. Precision shall not be more than 12 decimal places.
    /// - parameter level: Price at which to execute the working order.
    /// - parameter limit: The limit level/distance at which the user will like to take profit once the working order has been transformed into a position.
    /// - parameter stop: The stop level/distance at which the user doesn't want to incur more losses once the working order has been transformed into a position.
    /// - parameter forceOpen: Enabling force open when creating a new position or working order will enable a second position to be opened on a market.
    /// - parameter expiration: Indicates when the working order expires if its triggers hasn't been met.
    /// - parameter reference: A user-defined reference (e.g. `RV3JZ2CWMHG1BK`) identifying the submission of the order. If `nil` a reference will be created by the server and return as the result of this enpoint.
    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
    public func create(epic: Epic, expiry: API.Instrument.Expiry = .none, currency: Currency.Code, direction: API.Deal.Direction,
                       type: API.WorkingOrder.Kind, size: Decimal, level: Decimal, limit: API.Deal.Limit?, stop: (type: API.Deal.Stop.Kind, risk: API.Deal.Stop.Risk)?, forceOpen: Bool = true,
                       expiration: API.WorkingOrder.Expiration, reference: API.Deal.Reference? = nil) -> SignalProducer<API.Deal.Reference,API.Error> {
        return SignalProducer(api: self.api) { (_) -> Self.PayloadCreation in
                return try .init(epic: epic, expiry: expiry, currency: currency, direction: direction, type: type, size: size, level: level, limit: limit, stop: stop, forceOpen: forceOpen, expiration: expiration, reference: reference)
            }.request(.post, "workingorders/otc", version: 2, credentials: true, body: { (_, payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperReference) in w.dealReference }
    }
    
    // MARK: PUT /workingorders/otc/{dealId}
    
    /// Updates an OTC working order.
    /// - parameter identifier: A permanent deal reference for a confirmed working order.
    /// - parameter type: The working order type.
    /// - parameter level: Price at which to execute the working order.
    /// - parameter limit: Passing a value, will set a limit level (replacing the previous one, if any). Setting this argument to `nil` will delete the limit on the working order.
    /// - parameter stop: Passing a value will set a stop level (replacing the previous one, if any). Setting this argument to `nil` will delete the stop working order.
    /// - parameter expiration: The time at which the working order deletes itself.
    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
    public func update(identifier: API.Deal.Identifier, type: API.WorkingOrder.Kind, level: Decimal, limit: API.Deal.Limit?, stop: API.Deal.Stop.Kind?, expiration: API.WorkingOrder.Expiration) -> SignalProducer<API.Deal.Reference,API.Error> {
        return SignalProducer(api: self.api) { (_) -> Self.PayloadUpdate in
                return try .init(type: type, level: level, limit: limit, stop: stop, expiration: expiration)
            }.request(.put, "workingorders/otc/\(identifier.rawValue)", version: 2, credentials: true, body: { (_, payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperReference) in w.dealReference }
    }
    
    // MARK: DELETE /workingorders/otc/{dealId}
    
    /// Deletes an OTC working order.
    /// - parameter identifier: A permanent deal reference for a confirmed working order.
    public func delete(identifier: API.Deal.Identifier) -> SignalProducer<API.Deal.Reference,API.Error> {
        return SignalProducer(api: self.api)
            .request(.delete, "workingorders/otc/\(identifier.rawValue)", version: 2, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperReference) in w.dealReference }
    }
    
}

// MARK: - Supporting Entities

extension API.Request.WorkingOrders {
    private struct PayloadCreation: Encodable {
        let epic: Epic
        let expiry: API.Instrument.Expiry
        let currency: Currency.Code
        let direction: API.Deal.Direction
        let type: API.WorkingOrder.Kind
        let level: Decimal
        let size: Decimal
        let limit: API.Deal.Limit?
        let stop: (type: API.Deal.Stop.Kind, risk: API.Deal.Stop.Risk)?
        let forceOpen: Bool
        let expiration: API.WorkingOrder.Expiration
        let reference: API.Deal.Reference?
        
        init(epic: Epic, expiry: API.Instrument.Expiry, currency: Currency.Code, direction: API.Deal.Direction, type: API.WorkingOrder.Kind, size: Decimal, level: Decimal, limit: API.Deal.Limit?, stop: (type: API.Deal.Stop.Kind, risk: API.Deal.Stop.Risk)?, forceOpen: Bool, expiration: API.WorkingOrder.Expiration, reference: API.Deal.Reference?) throws {
            self.epic = epic
            self.expiry = expiry
            self.currency = currency
            self.direction = direction
            self.type = type
            // Check the size for negative numbers or zero.
            guard size.isNormal, case .plus = size.sign else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "Working order creation failed! The size value \"\(size)\" must be a valid number and greater than zero.")
            }
            // Check the limit for level/distance validity.
            if let limit = limit {
                guard limit.isValid(with: (level, direction)) else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The given limit is invalid. Limit: \(limit)")
                }
            }
            // Check the stop for level/distance validity and to verify that only the distance type allow limited risk.
            if let stop = stop {
                guard API.Deal.Stop(stop.type, risk: stop.risk, trailing: .static).isValid(with: (level, direction)) else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The given stop is invalid. Stop: \(stop)")
                }
                
                if case .limited = stop.risk, case .position = stop.type {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Only stop distances may be \"guaranteed stops\" (or limited risk).")
                }
            }
            // Check that the expiration date is at least one second later than now.
            if case .tillDate(let date) = expiration {
                guard date > Date(timeIntervalSinceNow: 1) else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The expiration date provided must be later than now + 1 sec.")
                }
            }
            self.size = size
            self.level = level
            self.limit = limit
            self.stop = stop
            self.forceOpen = forceOpen
            self.expiration = expiration
            self.reference = reference
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Self.CodingKeys.self)
            try container.encode(self.epic, forKey: .epic)
            try container.encode(self.expiry, forKey: .expiry)
            try container.encode(self.currency, forKey: .currency)
            try container.encode(self.direction, forKey: .direction)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.size, forKey: .size)
            try container.encode(self.level, forKey: .level)
            
            switch self.limit {
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
                case .limited: try container.encode(true,  forKey: .isStopGuaranteed)
                }
            } else {
                try container.encode(false, forKey: .isStopGuaranteed)
            }
            
            try container.encode(self.forceOpen, forKey: .forceOpen)
            
            switch self.expiration {
            case .tillCancelled:
                try container.encode(API.WorkingOrder.Expiration.CodingKeys.tillCancelled.rawValue, forKey: .expiration)
            case .tillDate(let date):
                try container.encode(API.WorkingOrder.Expiration.CodingKeys.tillDate.rawValue, forKey: .expiration)
                try container.encode(date, forKey: .expirationDate, with: API.TimeFormatter.humanReadable)
            }
            try container.encodeIfPresent(self.reference, forKey: .reference)
        }
        
        private enum CodingKeys: String, CodingKey {
            case epic, expiry
            case currency = "currencyCode"
            case direction, type, size, level
            case limitLevel, limitDistance
            case stopLevel, stopDistance, isStopGuaranteed = "guaranteedStop"
            case forceOpen
            case expiration = "timeInForce"
            case expirationDate = "goodTillDate"
            case reference = "dealReference"
        }
    }
}

extension API.Request.WorkingOrders {
    private struct PayloadUpdate: Encodable {
        let type: API.WorkingOrder.Kind
        let level: Decimal
        let limit: API.Deal.Limit?
        let stop: API.Deal.Stop.Kind?
        let expiration: API.WorkingOrder.Expiration
        
        init(type: API.WorkingOrder.Kind, level: Decimal, limit: API.Deal.Limit?, stop: API.Deal.Stop.Kind?, expiration: API.WorkingOrder.Expiration) throws {
            // Check that the limit distance is a positive number (if it is set).
            if case .distance(let distance) = limit {
                guard distance.isNormal, case .plus = distance.sign else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The limit distance \"\(distance)\" must be a valid number and greater than zero.")
                }
            }
            // Check that the stop distance is a positive number (if it is set).
            if case .distance(let distance) = stop {
                guard distance.isNormal, case .plus = distance.sign else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The stop distance \"\(distance)\" must be a valid number and greater than zero.")
                }
            }
            // Check that the expiration date is at least one second later than now.
            if case .tillDate(let date) = expiration {
                guard date > Date(timeIntervalSinceNow: 1) else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The expiration date provided must be later than now + 1 sec.")
                }
            }
            self.type = type
            self.level = level
            self.limit = limit
            self.stop = stop
            self.expiration = expiration
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Self.CodingKeys.self)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.level, forKey: .level)
            
            switch self.limit {
            case .none: break
            case .position(let level): try container.encode(level, forKey: .limitLevel)
            case .distance(let dista): try container.encode(dista, forKey: .limitDistance)
            }
            
            switch stop {
            case .none: break
            case .position(let level): try container.encode(level, forKey: .stopLevel)
            case .distance(let dista): try container.encode(dista, forKey: .stopDistance)
            }
            
            switch self.expiration {
            case .tillCancelled:
                try container.encode(API.WorkingOrder.Expiration.CodingKeys.tillCancelled.rawValue, forKey: .expiration)
            case .tillDate(let date):
                try container.encode(API.WorkingOrder.Expiration.CodingKeys.tillDate.rawValue, forKey: .expiration)
                try container.encode(date, forKey: .expirationDate, with: API.TimeFormatter.humanReadable)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case type, level
            case limitLevel, limitDistance
            case stopLevel, stopDistance
            case expiration = "timeInForce"
            case expirationDate = "goodTillDate"
        }
    }
}

// MARK: Response Entities

extension API.Request.WorkingOrders {
    private struct WrapperReference: Decodable {
        let dealReference: API.Deal.Reference
    }
}
