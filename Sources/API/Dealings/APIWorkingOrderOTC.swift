import ReactiveSwift
import Foundation

extension API.Request.WorkingOrders {
    
    // MARK: POST /workingorders/otc
    
    
    
    // MARK: PUT /workingorders/otc/{dealId}
    
    
    
    // MARK: DELETE /workingorders/otc/{dealId}
    
    
    
}

// MARK: - Supporting Entities

//extension API {
//    /// Creates an OTC working order.
//    /// - parameter request: Data for the new working order, with some in-client validation.
//    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
//    public func createWorkingOrder(_ request: API.Request.WorkingOrder.Creation) -> SignalProducer<String,API.Error> {
//        return SignalProducer(api: self)
//            .request(.post, "workingorders/otc", version: 2, credentials: true, body: { (_,_) in
//                (.json, try JSONEncoder().encode(request))
//            }).send(expecting: .json)
//            .validateLadenData(statusCodes: 200)
//            .decodeJSON()
//            .map { (w: API.Response.WorkingOrder.ReferenceWrapper) in w.dealReference }
//    }
//    
//    /// Updates an OTC working order.
//    ///
//    /// This method changes one or many of the given parameters. Arguments not given are not modified.
//    /// - parameter request: Data for the new working order, with some in-client validation.
//    public func updateWorkingOrder(identifier dealId: String, type: API.WorkingOrder.Kind? = nil, level: Double? = nil, limit: API.WorkingOrder.Boundary.Limit? = nil, stop: API.WorkingOrder.Boundary.Stop? = nil, expiration: API.WorkingOrder.Expiration? = nil) -> SignalProducer<String,API.Error> {
//        return SignalProducer(api: self) { (_) -> API.Request.WorkingOrder.Update in
//                guard !dealId.isEmpty else {
//                    throw API.Error.invalidRequest(underlyingError: nil, message: "Working order update failed! The deal identifier cannot be empty.")
//                }
//            
//                guard let payload = API.Request.WorkingOrder.Update(type: type, level: level, limit: limit, stop: stop, expiration: expiration) else {
//                    throw API.Error.invalidRequest(underlyingError: nil, message: "Working order update failed! No parameters were provided.")
//                }
//                return payload
//            }.request(.put, "workingorders/otc/\(dealId)", version: 2, credentials: true, body: { (_,payload) in
//                (.json, try JSONEncoder().encode(payload))
//            }).send(expecting: .json)
//            .validateLadenData(statusCodes: 200)
//            .decodeJSON()
//            .map { (w: API.Response.WorkingOrder.ReferenceWrapper) in w.dealReference }
//        
//    }
//    
//    /// Closes/Deletes the targeted working order.
//    /// - parameter dealId: A permanent deal reference for a confirmed trade.
//    /// - returns: The transient deal reference (for an unconfirmed trade) wrapped in a SignalProducer's value.
//    public func deleteWorkingOrder(identifier dealId: String) -> SignalProducer<String,API.Error> {
//        return SignalProducer(api: self)
//            .request(.delete, "workingorders/otc/\(dealId)", version: 2, credentials: true)
//            .send(expecting: .json)
//            .validateLadenData(statusCodes: 200)
//            .decodeJSON()
//            .map { (w: API.Response.WorkingOrder.ReferenceWrapper) in w.dealReference }
//    }
//}
//
//// MARK: -
//
//extension API.Request {
//    /// List of OTC working order requests.
//    public enum WorkingOrder { }
//}
//
//extension API.Request.WorkingOrder {
//    /// Information needed to create an OTC working order.
//    public struct Creation: Encodable {
//        /// A user-defined reference identifying the submission of the order.
//        ///
//        /// Example of deal reference: `RV1JZ1CHMWG2KB`
//        public let reference: String?
//        /// Instrument epic identifer.
//        public let epic: String
//        /// Instrument expiration date.
//        ///
//        /// The date (and sometimes time) at which a spreadbet or CFD will automatically close against some predefined market value should the bet remain open beyond its last dealing time. Some CFDs do not expire, and have an expiry of '-'. eg DEC-14, or DFB for daily funded bets.
//        public let expiry: API.Expiry
//        /// The currency code (3 letters).
//        public let currency: String
//        /// Deal size.
//        ///
//        /// Precision shall not be more than 12 decimal places.
//        public let size: Double
//        /// Deal direction
//        public let direction: API.Position.Direction
//        /// Price at which to execute the trade.
//        public let level: Double
//        /// The level boundaries.
//        public let boundaries: API.Response.WorkingOrder.Boundaries
//        /// Describes when the working order will expire.
//        public let expiration: API.WorkingOrder.Expiration
//        /// The working order type.
//        public let type: API.WorkingOrder.Kind
//        /// Boolean indicating whether "force open" is required.
//        ///
//        /// Enabling force open when creating a new position (or working order) will enable a second position to be opened on a market. Working orders (orders to open) have this set to true by default.
//        public let requiresForceOpen: Bool
//        
//        /// Designated initializer which holds all the information needed at the working order's creation time.
//        public init(_ expiration: API.WorkingOrder.Expiration, epic: String, expiry: API.Expiry = .none, currency: String, size: Double, direction: API.Position.Direction, level: Double, boundaries: API.Response.WorkingOrder.Boundaries? = nil, type: API.WorkingOrder.Kind, forceOpen: Bool = false, reference: String? = nil) {
//            self.reference = reference
//            self.epic = epic
//            self.expiry = expiry
//            self.currency = currency
//            self.size = size
//            self.direction = direction
//            self.level = level
//            self.boundaries = boundaries ?? API.Response.WorkingOrder.Boundaries(limit: nil, stop: nil, isGuaranteed: nil)
//            self.expiration = expiration
//            self.type = type
//            self.requiresForceOpen = forceOpen
//        }
//        
//        public func encode(to encoder: Encoder) throws {
//            var container = encoder.container(keyedBy: CodingKeys.self)
//            try container.encodeIfPresent(self.reference, forKey: .reference)
//            try container.encode(self.epic, forKey: .epic)
//            try container.encode(self.expiry, forKey: .expiry)
//            try container.encode(self.currency, forKey: .currency)
//            try container.encode(self.size, forKey: .size)
//            try container.encode(self.direction, forKey: .direction)
//            try container.encode(self.level, forKey: .level)
//            try self.boundaries.encode(to: encoder)
//            try container.encode(self.type, forKey: .type)
//            try container.encode(self.requiresForceOpen, forKey: .requiresForceOpen)
//            try container.encode(self.expiration.rawValue, forKey: .expiration)
//            if case .tillDate(let date) = self.expiration {
//                let dateString = API.DateFormatter.humanReadable.string(from: date)
//                try container.encode(dateString, forKey: .expirationDate)
//            }
//        }
//        
//        private enum CodingKeys: String, CodingKey {
//            case reference = "dealReference"
//            case epic, expiry
//            case currency = "currencyCode"
//            case size
//            case direction
//            case level
//            case expiration = "timeInForce"
//            case expirationDate = "goodTillDate"
//            case type
//            case requiresForceOpen = "forceOpen"
//        }
//    }
//}
//
//extension API.Request.WorkingOrder {
//    /// Information needed to update a confirmed working order.
//    fileprivate struct Update: Encodable {
//        /// The working order type.
//        let type: API.WorkingOrder.Kind?
//        /// Price at which to execute the trade.
//        let level: Double?
//        /// The limit level at which the user is happy with his/her profits.
//        let limit: API.WorkingOrder.Boundary.Limit?
//        /// The stop level at which the user doesn't want to take more losses.
//        let stop: API.WorkingOrder.Boundary.Stop?
//        /// Describes when the working order will expire.
//        let expiration: API.WorkingOrder.Expiration?
//        
//        init?(type: API.WorkingOrder.Kind?, level: Double?, limit: API.WorkingOrder.Boundary.Limit?, stop: API.WorkingOrder.Boundary.Stop?, expiration: API.WorkingOrder.Expiration?) {
//            guard (type != nil) || (level != nil) || (limit != nil) || (stop != nil) || (expiration != nil) else { return nil }
//            self.type = type
//            self.level = level
//            self.limit = limit
//            self.stop = stop
//            self.expiration = expiration
//        }
//        
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
//
//// MARK: -
//
//extension API.Response.WorkingOrder {
//    /// Wrapper around a single deal reference.
//    fileprivate struct ReferenceWrapper: Decodable {
//        // The transient deal reference (for an unconfirmed trade)
//        let dealReference: String
//        /// Do not call! The only way to initialize is through `Decodable`.
//        private init?() { fatalError("Unaccessible initializer") }
//    }
//}
