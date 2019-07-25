import ReactiveSwift
import Foundation

extension API.Request.WorkingOrders {
    
    // MARK: GET /workingorders
    
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to API working orders.
    public struct WorkingOrders {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        internal unowned let api: API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        init(api: API) {
            self.api = api
        }
    }
}

//extension API {
//    /// Returns all open working orders for the active account.
//    public func workingOrders() -> SignalProducer<[API.Response.WorkingOrder],API.Error> {
//        return SignalProducer(api: self)
//            .request(.get, "workingorders", version: 2, credentials: true)
//            .send(expecting: .json)
//            .validateLadenData(statusCodes: 200)
//            .decodeJSON()
//            .map { (w: API.Response.WorkingOrderListWrapper) in w.workingOrders }
//    }
//}
//
//extension API.Response {
//    /// Wrapper around a list of working orders.
//    fileprivate struct WorkingOrderListWrapper: Decodable {
//        let workingOrders: [WorkingOrder]
//        /// Do not call! The only way to initialize is through `Decodable`.
//        private init?() { fatalError("Unaccessible initializer") }
//    }
//
//    /// An order that has not yet been executed.
//    public struct WorkingOrder: Decodable {
//        /// Permanent deal reference for a confirmed trade.
//        public let identifier: String
//        /// Instrument epic identifier.
//        public let epic: String
//        /// Date when the order was created.
//        public let date: Date
//        /// Currency ISO code.
//        public let currency: String
//        /// Deal direction.
//        public let direction: API.Position.Direction
//        /// The working order type.
//        public let type: API.WorkingOrder.Kind
//        /// Price at which to execute the trade.
//        public let level: Double
//        /// The level boundaries.
//        public let boundaries: Boundaries
//        /// Describes when the working order will expire.
//        public let expiration: API.WorkingOrder.Expiration
//        /// Is the working order a direct market access order?
//        ///
//        /// Direct market access is a way of directly interacting with the order book of an exchange.
//        public let isDirectMarket: Bool
//
//        /// The market basic information and snapshot.
//        public let market: API.Response.Watchlist.Market
//
//        public init(from decoder: Decoder) throws {
//            let container = try decoder.container(keyedBy: CodingKeys.self)
//            self.market = try container.decode(API.Response.Watchlist.Market.self, forKey: .market)
//
//            let nestedContainer = try container.nestedContainer(keyedBy: CodingKeys.NestedKeys.self, forKey: .info)
//            self.identifier = try nestedContainer.decode(String.self, forKey: .identifier)
//            self.epic = try nestedContainer.decode(String.self, forKey: .epic)
//            self.date = try nestedContainer.decode(Date.self, forKey: .date, with: API.DateFormatter.iso8601NoTimezone)
//            self.currency = try nestedContainer.decode(String.self, forKey: .currency)
//
//            self.direction = try nestedContainer.decode(API.Position.Direction.self, forKey: .direction)
//            self.type = try nestedContainer.decode(API.WorkingOrder.Kind.self, forKey: .type)
//            self.level = try nestedContainer.decode(Double.self, forKey: .level)
//            self.boundaries = try container.decode(Boundaries.self, forKey: .info)
//            self.isDirectMarket = try nestedContainer.decode(Bool.self, forKey: .isDirectMarket)
//
//            let expirationString = try nestedContainer.decode(String.self, forKey: .expiration)
//            let expirationDate = try nestedContainer.decodeIfPresent(Date.self, forKey: .expirationDate, with: API.DateFormatter.iso8601NoTimezone)
//            do {
//                self.expiration = try API.WorkingOrder.Expiration(expirationString, date: expirationDate)
//            } catch let error {
//                throw DecodingError.dataCorruptedError(forKey: .expiration, in: nestedContainer, debugDescription: "Underlying expiration error: \(error)")
//            }
//        }
//
//        private enum CodingKeys: String, CodingKey {
//            case info = "workingOrderData"
//            case market = "marketData"
//
//            enum NestedKeys: String, CodingKey {
//                case identifier = "dealId"
//                case epic
//                case date = "createdDateUTC"
//                case currency = "currencyCode"
//                case direction
//                case level = "orderLevel"
//                case expiration = "timeInForce"
//                case expirationDate = "goodTillDateISO"
//                case type = "orderType"
//                case isDirectMarket = "dma"
//            }
//        }
//    }
//}
//
//extension API.Response.WorkingOrder {
//    /// Display the price/level boundaries for the given deal.
//    public struct Boundaries: Codable {
//        /// The limit level at which the user is happy with his/her profits.
//        ///
//        /// It can be marked as a distance from the buy/sell level, or as an absolute value, or none (in which the position is open).
//        public let limit: API.WorkingOrder.Boundary.Limit?
//        /// The stop level at which the user don't want to take more losses.
//        ///
//        /// It can be marked as a distance from the buy/sell level, or as an absolute value, or none (in which the position is open).
//        public let stop: API.WorkingOrder.Boundary.Stop?
//        /// Boolean indicating if a guaranteed stop is required.
//        ///
//        /// A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
//        /// - note: Guaranteed stops come at the price of an increased spread
//        public let isStopGuaranteed: Bool
//        /// Returns a boolean indicating whether there are no boundaries set.
//        public var isEmpty: Bool { return (self.limit == nil) && (self.stop == nil) }
//
//        /// Designated initializer.
//        public init(limit: API.WorkingOrder.Boundary.Limit?, stop: API.WorkingOrder.Boundary.Stop?, isGuaranteed: Bool?) {
//            self.limit = limit
//            self.stop = stop
//            self.isStopGuaranteed = isGuaranteed ?? false
//        }
//
//        public init(from decoder: Decoder) throws {
//            let container = try decoder.container(keyedBy: CodingKeys.self)
//            if let limitLevel = try container.decodeIfPresent(Double.self, forKey: .limitLevel) {
//                self.limit = .position(limitLevel)
//            } else if let limitDistance = try container.decodeIfPresent(Double.self, forKey: .limitDistance) {
//                self.limit = .distance(limitDistance)
//            } else {
//                self.limit = nil
//            }
//
//            if let stopLevel = try container.decodeIfPresent(Double.self, forKey: .stopLevel) {
//                self.stop = .position(stopLevel)
//            } else if let stopDistance = try container.decodeIfPresent(Double.self, forKey: .stopDistance) {
//                self.stop = .distance(stopDistance)
//            } else {
//                self.stop = nil
//            }
//
//            self.isStopGuaranteed = try container.decodeIfPresent(Bool.self, forKey: .isStopGuaranteed) ?? false
//        }
//
//        public func encode(to encoder: Encoder) throws {
//            var container = encoder.container(keyedBy: CodingKeys.self)
//            try container.encode(self.isStopGuaranteed, forKey: .isStopGuaranteed)
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
//        }
//
//        private enum CodingKeys: String, CodingKey {
//            case limitLevel = "limitLevel"
//            case limitDistance = "limitDistance"
//            case stopDistance = "stopDistance"
//            case stopLevel = "stopLevel"
//            case isStopGuaranteed = "guaranteedStop"
//        }
//    }
//}
