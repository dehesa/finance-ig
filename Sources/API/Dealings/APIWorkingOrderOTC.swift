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
                       type: API.WorkingOrder.Kind, size: Double, level: Double, limit: API.Deal.Limit?, stop: Self.Stop?, forceOpen: Bool = true,
                       expiration: API.WorkingOrder.Expiration, reference: API.Deal.Reference? = nil) -> SignalProducer<API.Deal.Reference,API.Error> {
        return SignalProducer(api: self.api)
            .request(.post, "workingorders/otc", version: 2, credentials: true, body: { (_,_) in
                let payload: Self.PayloadCreation = .init(epic: epic, expiry: expiry, currency: currency, direction: direction, type: type, level: level, size: size, limit: limit, stop: stop, forceOpen: forceOpen, expiration: expiration, reference: reference)
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
    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
    public func update(identifier: API.Deal.Identifier, type: API.WorkingOrder.Kind, level: Double, limit: API.Deal.Limit?, stop: Self.Stop?, expiration: API.WorkingOrder.Expiration?) -> SignalProducer<API.Deal.Reference,API.Error> {
        return SignalProducer(api: self.api)
            .request(.put, "workingorders/otc/\(identifier.rawValue)", version: 2, credentials: true, body: { (_,_) in
                let payload: Self.PayloadUpdate = .init(identifier: identifier, type: type, level: level, limit: limit, stop: stop, expiration: expiration)
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
    /// The level/price at which the user doesn't want to incur more lose.
    public enum Stop {
        /// Absolute level where to place the stop loss.
        /// - parameter level: The absolute stop level (e.g. 1.653 USD/EUR).
        /// - parameter isGuaranteed: Boolean indicating if a guaranteed stop is required. A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
        case position(level: Double)
        /// Distance from the buy/sell level where the stop will be placed.
        /// - parameter isGuaranteed: Boolean indicating if a guaranteed stop is required. A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
        case distance(Double, isGuaranteed: Bool)
    }
    
    private struct PayloadCreation: Encodable {
        let epic: Epic
        let expiry: API.Instrument.Expiry
        let currency: Currency.Code
        let direction: API.Deal.Direction
        let type: API.WorkingOrder.Kind
        let level: Double
        let size: Double
        let limit: API.Deal.Limit?
        let stop: API.Request.WorkingOrders.Stop?
        let forceOpen: Bool
        let expiration: API.WorkingOrder.Expiration
        let reference: API.Deal.Reference?
        
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
            case .distance(let distance): try container.encode(distance, forKey: .limitDistance)
            }
            
            switch self.stop {
            case .none:
                try container.encode(false, forKey: .isStopGuaranteed)
            case .position(let level): try container.encode(level, forKey: .stopLevel)
            case .distance(let distance, let isGuaranteed):
                try container.encode(distance, forKey: .stopDistance)
                try container.encode(isGuaranteed, forKey: .isStopGuaranteed)
            }
            
            try container.encode(self.forceOpen, forKey: .forceOpen)
            
            typealias ExpirationKeys = API.WorkingOrder.Expiration.CodingKeys
            switch self.expiration {
            case .tillCancelled:
                try container.encode(ExpirationKeys.tillCancelled.rawValue, forKey: .expiration)
            case .tillDate(let date):
                try container.encode(ExpirationKeys.tillDate.rawValue, forKey: .expiration)
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
    
    private struct PayloadUpdate: Encodable {
        let identifier: API.Deal.Identifier
        let type: API.WorkingOrder.Kind
        let level: Double
        let limit: API.Deal.Limit?
        let stop: API.Request.WorkingOrders.Stop?
        let expiration: API.WorkingOrder.Expiration?
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Self.CodingKeys.self)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.level, forKey: .level)
            
            switch self.limit {
            case .none:
                try container.encodeNil(forKey: .limitLevel)
                try container.encodeNil(forKey: .limitDistance)
            case .position(let level):
                try container.encode(level, forKey: .limitLevel)
            case .distance(let distance):
                try container.encode(distance, forKey: .limitDistance)
            }
            
            switch self.stop {
            case .none:
                try container.encodeNil(forKey: .stopLevel)
                try container.encodeNil(forKey: .stopDistance)
            case .position(let level):
                try container.encode(level, forKey: .stopLevel)
            case .distance(let distance, let isGuaranteed):
                guard !isGuaranteed else {
                    let ctx = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Updating a stop working order will always make the stop exposed to risk.")
                    throw EncodingError.invalidValue(self.stop!, ctx)
                }
                try container.encode(distance, forKey: .stopDistance)
            }
            
            typealias ExpirationKeys = API.WorkingOrder.Expiration.CodingKeys
            switch self.expiration {
            case .none:
                try container.encodeNil(forKey: .expiration)
            case .tillCancelled:
                try container.encode(ExpirationKeys.tillCancelled.rawValue, forKey: .expiration)
            case .tillDate(let date):
                try container.encode(ExpirationKeys.tillDate.rawValue, forKey: .expiration)
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

//        func encode(to encoder: Encoder) throws {
//            var container = encoder.container(keyedBy: CodingKeys.self)
//            try container.encodeIfPresent(self.type, forKey: .type)
//            try container.encodeIfPresent(self.level, forKey: .level)
//            
//            if let limit = self.limit {
//                switch limit {
//                case .position(let level): try container.encode(level, forKey: .limitLevel)
//                case .distance(let dista): try container.encode(dista, forKey: .limitDistance)
//                }
//            }
//            
//            if let stop = self.stop {
//                switch stop {
//                case .position(let level): try container.encode(level, forKey: .stopLevel)
//                case .distance(let dista): try container.encode(dista, forKey: .stopDistance)
//                }
//            }
//            
//            if let expiration = self.expiration {
//                try container.encode(expiration.rawValue, forKey: .expiration)
//                if case .tillDate(let date) = expiration {
//                    try container.encode(date, forKey: .expirationDate, with: API.DateFormatter.humanReadable)
//                }
//            }
//        }
//        
//        private enum CodingKeys: String, CodingKey {
//            case type
//            case level
//            case limitLevel = "limitLevel"
//            case limitDistance = "limitDistance"
//            case stopDistance = "stopDistance"
//            case stopLevel = "stopLevel"
//            case expiration = "timeInForce"
//            case expirationDate = "goodTillDate"
//        }
//    }
//}
