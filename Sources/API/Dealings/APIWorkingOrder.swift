import ReactiveSwift
import Foundation

extension API.Request.WorkingOrders {
    
    // MARK: GET /workingorders
    
    /// Returns all open working orders for the active account.
    /// - returns: A `SignalProducer` delivering in its value a list of all open working orders.
    public func getAll() -> SignalProducer<[API.WorkingOrder],API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "workingorders", version: 2, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperList) in w.workingOrders }
    }
    
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

// MARK: Response Entity

extension API.Request.WorkingOrders {
    private struct WrapperList: Decodable {
        let workingOrders: [API.WorkingOrder]
    }
}

extension API {
    /// Working order awaiting for its trigger to be met.
    public struct WorkingOrder: Decodable {
        /// Permanent deal reference for a confirmed trade.
        public let identifier: API.Deal.Identifier
        /// Date when the order was created.
        public let date: Date
        /// Instrument epic identifier.
        public let epic: Epic
        /// Currency ISO code.
        public let currency: Currency.Code
        /// Deal direction.
        public let direction: API.Deal.Direction
        /// The working order type.
        public let type: Self.Kind
        /// Deal size.
        public let size: Double
        /// Price at which to execute the trade.
        public let level: Double
        /// The distance from `level` at which the limit will be set once the order is fulfilled.
        public let limitDistance: Double?
        /// The distance from `level` at which the stop will be set once the order is fulfilled.
        public let stop: (distance: Double, risk: API.Position.Stop.Risk)?
        /// A way of directly interacting with the order book of an exchange.
        public let isDirectlyAccessingMarket: Bool
        /// Indicates when the working order expires if its triggers hasn't been met.
        public let expiration: Self.Expiration
        /// The market basic information and snapshot.
        public let market: API.Node.Market
        
        public init(from decoder: Decoder) throws {
            let topContainer = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            let container = try topContainer.nestedContainer(keyedBy: Self.CodingKeys.WorkingOrderKeys.self, forKey: .workingOrder)
            self.identifier = try container.decode(API.Deal.Identifier.self, forKey: .identifier)
            self.date = try container.decode(Date.self, forKey: .date, with: API.TimeFormatter.iso8601NoTimezone)
            self.epic = try container.decode(Epic.self, forKey: .epic)
            self.currency = try container.decode(Currency.Code.self, forKey: .currency)
            self.direction = try container.decode(API.Deal.Direction.self, forKey: .direction)
            self.type = try container.decode(API.WorkingOrder.Kind.self, forKey: .type)
            self.size = try container.decode(Double.self, forKey: .size)
            self.level = try container.decode(Double.self, forKey: .level)
            self.limitDistance = try container.decodeIfPresent(Double.self, forKey: .limitDistance)
            if let stopDistance = try container.decodeIfPresent(Double.self, forKey: .stopDistance) {
                if try container.decode(Bool.self, forKey: .isStopGuaranteed) {
                    let premium = try container.decodeIfPresent(Double.self, forKey: .stopRiskPremium)
                    self.stop = (distance: stopDistance, risk: .limited(premium: premium))
                } else {
                    self.stop = (distance: stopDistance, risk: .exposed)
                }
            } else {
                self.stop = nil
            }
            self.isDirectlyAccessingMarket = try container.decode(Bool.self, forKey: .isDirectlyAccessingMarket)
            
            let expirationType = try container.decode(String.self, forKey: .expiration)
            switch expirationType {
            case Self.Expiration.CodingKeys.tillCancelled.rawValue:
                self.expiration = .tillCancelled
            case Self.Expiration.CodingKeys.tillDate.rawValue:
                let date = try container.decode(Date.self, forKey: .expirationDate, with: API.TimeFormatter.iso8601NoTimezoneSeconds)
                self.expiration = .tillDate(date)
            default:
                throw DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: "The working order expiration \"\(expirationType)\" couldn't be processed.")
            }
            
            self.market = try topContainer.decode(API.Node.Market.self, forKey: .market)
        }
        
        private enum CodingKeys: String, CodingKey {
            case workingOrder = "workingOrderData"
            case market = "marketData"
            
            enum WorkingOrderKeys: String, CodingKey {
                case identifier = "dealId"
                case date = "createdDateUTC"
                case epic
                case currency = "currencyCode"
                case direction
                case type = "orderType"
                case size = "orderSize"
                case level = "orderLevel"
                case limitDistance
                case stopDistance
                case isStopGuaranteed = "guaranteedStop"
                case stopRiskPremium = "limitedRiskPremium"
                case isDirectlyAccessingMarket = "dma"
                case expiration = "timeInForce"
                case expirationDate = "goodTillDateISO"
            }
        }
    }
}
