import Combine
import Foundation
import Decimals

extension API.Request.Deals {
    
    // MARK: GET /workingorders
    
    /// Returns all open working orders for the active account.
    /// - returns: Publisher forwarding all open working orders.
    public func getWorkingOrders() -> AnyPublisher<[API.WorkingOrder],IG.Error> {
        self.api.publisher
            .makeRequest(.get, "workingorders", version: 2, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(date: true)) { (w: _WrapperList, _) in w.workingOrders }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: POST /workingorders/otc
    
    /// Creates an OTC working order.
    /// - parameter reference: A user-defined reference (e.g. `RV3JZ2CWMHG1BK`) identifying the submission of the order. If `nil` a reference will be created by the server and return as the result of this enpoint. 
    /// - parameter epic: Instrument epic identifer.
    /// - parameter expiry: The date (and sometimes "time") at which a spreadbet or CFD will automatically close against some predefined market value should the bet remain open beyond its last dealing time. Some CFDs do not expire.
    /// - parameter currency: The currency code (3 letters).
    /// - parameter direction: Deal direction (whether buy or sell).
    /// - parameter type: The working order type.
    /// - parameter expiration: Indicates when the working order expires if its triggers hasn't been met.
    /// - parameter size: Deal size. Precision shall not be more than 12 decimal places.
    /// - parameter level: Price at which to execute the working order.
    /// - parameter limit: The limit level/distance at which the user will like to take profit once the working order has been transformed into a position.
    /// - parameter stop: The stop level/distance at which the user doesn't want to incur more losses once the working order has been transformed into a position. Trailing stops are not allowed on working orders.
    /// - parameter forceOpen: Enabling force open when creating a new position or working order will enable a second position to be opened on a market.
    /// - returns: Publisher forwarding the transient deal reference (for an unconfirmed trade).
    public func createWorkingOrder(reference: IG.Deal.Reference? = nil, epic: IG.Market.Epic, expiry: IG.Market.Expiry = .none, currency: Currency.Code, direction: IG.Deal.Direction, type: IG.Deal.WorkingOrder, expiration: IG.Deal.WorkingOrder.Expiration, size: Decimal64, level: Decimal64, limit: IG.Deal.Boundary?, stop: API.Request.Deals.WorkingOrder.Stop?, forceOpen: Bool = true) -> AnyPublisher<IG.Deal.Reference,IG.Error> {
        self.api.publisher { _ in
                try _PayloadCreation(epic: epic, expiry: expiry, currency: currency, direction: direction, type: type, size: size, level: level, limit: limit, stop: stop, forceOpen: forceOpen, expiration: expiration, reference: reference)
            }.makeRequest(.post, "workingorders/otc", version: 2, credentials: true, body: {
                (.json, try JSONEncoder().encode($0))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: Self.WrapperReference, _) in w.dealReference }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: PUT /workingorders/otc/{dealId}
    
    /// Updates an OTC working order.
    /// - attention: The returned reference is distinct from any previous working order reference (there is no way to set up an amended reference).
    /// - parameter id: A permanent deal reference for a confirmed working order.
    /// - parameter type: The working order type.
    /// - parameter expiration: Indicates when the working order expires if its triggers hasn't been met.
    /// - parameter level: Price at which to execute the working order.
    /// - parameter limit: Passing a value, will set a limit level (replacing the previous one, if any). Setting this argument to `nil` will delete the limit on the working order.
    /// - parameter stop: Passing a value will set a stop level (replacing the previous one, if any). Setting this argument to `nil` will delete the stop working order.
    /// - returns: Publisher forwarding the transient deal reference (for an unconfirmed trade).
    public func updateWorkingOrder(id: IG.Deal.Identifier, type: IG.Deal.WorkingOrder, expiration: IG.Deal.WorkingOrder.Expiration, level: Decimal64, limit: IG.Deal.Boundary?, stop: IG.Deal.Boundary?) -> AnyPublisher<IG.Deal.Reference,IG.Error> {
        self.api.publisher { _ in
                try _PayloadUpdate(type: type, level: level, limit: limit, stop: stop, expiration: expiration)
            }.makeRequest(.put, "workingorders/otc/\(id)", version: 2, credentials: true, body: {
                (.json, try JSONEncoder().encode($0))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: Self.WrapperReference, _) in w.dealReference }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: DELETE /workingorders/otc/{dealId}
    
    /// Deletes an OTC working order.
    /// - parameter id: A permanent deal reference for a confirmed working order.
    /// - returns: Publisher forwarding the deal reference.
    public func deleteWorkingOrder(id: IG.Deal.Identifier) -> AnyPublisher<IG.Deal.Reference,IG.Error> {
        self.api.publisher
            .makeRequest(.delete, "workingorders/otc/\(id)", version: 2, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: Self.WrapperReference, _) in w.dealReference }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
}

// MARK: - Request Entities

extension API.Request.Deals {
    public enum WorkingOrder {
        /// The level/price at which the user doesn't want to incur more lose.
        public enum Stop: Equatable {
            /// Absolute value of the stop (e.g. 1.653 USD/EUR).
            case level(Decimal64, risk: IG.Deal.Stop.Risk = .exposed)
            /// Relative stop over an undisclosed reference level.
            case distance(Decimal64, risk: IG.Deal.Stop.Risk = .exposed)
        }
        
        /// The level/price at which the user doesn't want to incur more lose.
        public enum StopEdit: Equatable {
            /// Relative stop over an undisclosed reference level.
            case distance(Decimal64, risk: IG.Deal.Stop.Risk = .exposed)
        }
    }
}

extension API.Request.Deals {
    private struct _PayloadCreation: Encodable {
        let epic: IG.Market.Epic
        let expiry: IG.Market.Expiry
        let currency: Currency.Code
        let direction: IG.Deal.Direction
        let type: IG.Deal.WorkingOrder
        let size: Decimal64
        let level: Decimal64
        let limit: IG.Deal.Boundary?
        let stop: API.Request.Deals.WorkingOrder.Stop?
        let forceOpen: Bool
        let expiration: IG.Deal.WorkingOrder.Expiration
        let reference: IG.Deal.Reference?
        
        init(epic: IG.Market.Epic, expiry: IG.Market.Expiry, currency: Currency.Code, direction: IG.Deal.Direction, type: IG.Deal.WorkingOrder, size: Decimal64, level: Decimal64, limit: IG.Deal.Boundary?, stop: API.Request.Deals.WorkingOrder.Stop?, forceOpen: Bool, expiration: IG.Deal.WorkingOrder.Expiration, reference: IG.Deal.Reference?) throws {
            self.reference = reference
            self.epic = epic
            self.expiry = expiry
            self.currency = currency
            self.direction = direction
            self.type = type
            
            guard size > .zero else { throw IG.Error(.api(.invalidRequest), "Invalid size '\(size)'.", help: "The position size must be a positive greater-than-zero number.") }
            self.size = size
            self.level = level
            
            if let limit = limit {
                switch (limit, direction) {
                case (.distance(let distance), _):
                    guard distance > 0 else { throw IG.Error(.api(.invalidRequest), "Invalid limit distance '\(distance)'.", help: "The limit distance must be a positive greater-than-zero number.") }
                case (.level(let limitLevel), .buy):
                    guard limitLevel > level else { throw IG.Error(.api(.invalidRequest), "Invalid limit level.", help: "The limit level must be above the order level for 'buy' deals.") }
                case (.level(let limitLevel), .sell):
                    guard limitLevel < level else { throw IG.Error(.api(.invalidRequest), "Invalid limit level.", help: "The limit level must be below the order level for 'sell' deals.") }
                }
                self.limit = limit
            } else { self.limit = nil }
            
            // If a stop is set, validate it.
            if let stop = stop {
                switch (stop, direction) {
                case (.level(let stopLevel, _), .buy):
                    guard stopLevel < level else { throw IG.Error(.api(.invalidRequest), "Invalid stop level.", help: "The stop level must be below the order level for 'buy' deals.") }
                case (.level(let stopLevel, _), .sell):
                    guard stopLevel > level else { throw IG.Error(.api(.invalidRequest), "Invalid stop level.", help: "The stop level must be above the order level for 'sell' deals.") }
                case (.distance(let distance, _), _):
                    guard distance > 0 else { throw IG.Error(.api(.invalidRequest), "Invalid stop distance.", help: "The stop distance must be a positive greater-than-zero number.") }
                }
                self.stop = stop
            } else { self.stop = nil }
            
            self.forceOpen = forceOpen
            
            switch expiration {
            case .tillCancelled: break
            case .tillDate(let date):
                guard date > Date(timeIntervalSinceNow: 1) else { throw IG.Error(.api(.invalidRequest), "Invalid working order expiration date.", help: "The expiration date must be later than the current date") }
            }
            self.expiration = expiration
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _Keys.self)
            try container.encodeIfPresent(self.reference, forKey: .reference)
            try container.encode(self.epic, forKey: .epic)
            try container.encode(self.expiry, forKey: .expiry)
            try container.encode(self.currency, forKey: .currency)
            try container.encode(self.direction, forKey: .direction)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.size, forKey: .size)
            try container.encode(self.level, forKey: .level)
            
            if let limit = self.limit {
                switch limit {
                case .level(let l): try container.encode(l, forKey: .limitLevel)
                case .distance(let d): try container.encode(d, forKey: .limitDistance)
                }
            }
            
            if let stop = self.stop {
                switch stop {
                case .level(let l, let r):
                    try container.encode(l, forKey: .stopLevel)
                    try container.encode(r == .limited, forKey: .isStopGuaranteed)
                case .distance(let d, let r):
                    try container.encode(d, forKey: .stopDistance)
                    try container.encode(r == .limited, forKey: .isStopGuaranteed)
                }
            } else {
                try container.encode(false, forKey: .isStopGuaranteed)
            }
            
            try container.encode(self.forceOpen, forKey: .forceOpen)
            
            switch self.expiration {
            case .tillCancelled:
                try container.encode("GOOD_TILL_CANCELLED", forKey: .expiration)
            case .tillDate(let date):
                try container.encode("GOOD_TILL_DATE", forKey: .expiration)
                try container.encode(date, forKey: .expirationDate, with: DateFormatter.humanReadable)
            }
        }
        
        private enum _Keys: String, CodingKey {
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

extension API.Request.Deals {
    private struct _PayloadUpdate: Encodable {
        let type: IG.Deal.WorkingOrder
        let level: Decimal64
        let limit: IG.Deal.Boundary?
        let stop: IG.Deal.Boundary?
        let expiration: IG.Deal.WorkingOrder.Expiration
        
        init(type: IG.Deal.WorkingOrder, level: Decimal64, limit: IG.Deal.Boundary?, stop: IG.Deal.Boundary?, expiration: IG.Deal.WorkingOrder.Expiration) throws {
            self.type = type
            self.level = level
            
            if let limit = limit {
                switch limit {
                case .level: break
                case .distance(let distance):
                    guard distance > 0 else { throw IG.Error(.api(.invalidRequest), "Invalid limit distance '\(distance)'.", help: "The limit distance must be a positive greater-than-zero number.") }
                }
                self.limit = limit
            } else { self.limit = nil }
            
            if let stop = stop {
                switch stop {
                case .level: break
                case .distance(let distance):
                    guard distance > 0 else { throw IG.Error(.api(.invalidRequest), "Invalid stop distance '\(distance)'.", help: "The stop distance must be a positive greater-than-zero number.") }
                }
                self.stop = stop
            } else { self.stop = nil }
            
            switch expiration {
            case .tillCancelled: break
            case .tillDate(let date):
                guard date > Date(timeIntervalSinceNow: 1) else { throw IG.Error(.api(.invalidRequest), "Invalid working order expiration date.", help: "The expiration date must be later than the current date") }
            }
            self.expiration = expiration
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _Keys.self)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.level, forKey: .level)
            
            if let limit = self.limit {
                switch limit {
                case .level(let l): try container.encode(l, forKey: .limitLevel)
                case .distance(let d): try container.encode(d, forKey: .limitDistance)
                }
            }
            
            if let stop = self.stop {
                switch stop {
                case .level(let l): try container.encode(l, forKey: .stopLevel)
                case .distance(let d): try container.encode(d, forKey: .stopDistance)
                }
            }
            
            switch self.expiration {
            case .tillCancelled:
                try container.encode("GOOD_TILL_CANCELLED", forKey: .expiration)
            case .tillDate(let date):
                try container.encode("GOOD_TILL_DATE", forKey: .expiration)
                try container.encode(date, forKey: .expirationDate, with: DateFormatter.humanReadable)
            }
        }
        
        private enum _Keys: String, CodingKey {
            case type, level
            case limitLevel, limitDistance
            case stopLevel, stopDistance
            case expiration = "timeInForce"
            case expirationDate = "goodTillDate"
        }
    }
}

// MARK: Response Entities

private extension API.Request.Deals {
    struct _WrapperList: Decodable {
        let workingOrders: [API.WorkingOrder]
    }
    
    struct WrapperReference: Decodable {
        let dealReference: IG.Deal.Reference
    }
}
