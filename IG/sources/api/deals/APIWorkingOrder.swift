import Combine
import Foundation
import Decimals

extension API.Request {
    /// List of endpoints related to API working orders.
    public struct WorkingOrders {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        internal unowned let api: API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        @usableFromInline internal init(api: API) { self.api = api }
    }
}

extension API.Request.WorkingOrders {
    
    // MARK: GET /workingorders
    
    /// Returns all open working orders for the active account.
    /// - returns: *Future* forwarding all open working orders.
    public func getAll() -> AnyPublisher<[API.WorkingOrder],API.Error> {
        self.api.publisher
            .makeRequest(.get, "workingorders", version: 2, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(date: true)) { (w: _WrapperList, _) in w.workingOrders }
            .mapError(API.Error.transform)
            .eraseToAnyPublisher()
    }
    
}

// MARK: - Entity

private extension API.Request.WorkingOrders {
    struct _WrapperList: Decodable {
        let workingOrders: [API.WorkingOrder]
    }
}

extension API {
    /// Working order awaiting for its trigger to be met.
    public struct WorkingOrder: Decodable {
        /// Permanent deal reference for a confirmed trade.
        public let identifier: IG.Deal.Identifier
        /// Date when the order was created.
        public let date: Date
        /// Instrument epic identifier.
        public let epic: IG.Market.Epic
        /// Currency ISO code.
        public let currencyCode: Currency.Code
        /// Deal direction.
        public let direction: IG.Deal.Direction
        /// The working order type.
        public let type: Self.Kind
        /// Deal size.
        public let size: Decimal64
        /// Price at which to execute the trade.
        public let level: Decimal64
        /// The level/distance at which the user is happy to take profit.
        public let limit: IG.Deal.Limit?
        /// The distance from `level` at which the stop will be set once the order is fulfilled.
        public let stop: IG.Deal.Stop?
        /// A way of directly interacting with the order book of an exchange.
        public let isDirectlyAccessingMarket: Bool
        /// Indicates when the working order expires if its triggers hasn't been met.
        public let expiration: Self.Expiration
        /// The market basic information and snapshot.
        public let market: API.Node.Market
        
        public init(from decoder: Decoder) throws {
            let topContainer = try decoder.container(keyedBy: _CodingKeys.self)
            self.market = try topContainer.decode(API.Node.Market.self, forKey: .market)
            
            let container = try topContainer.nestedContainer(keyedBy: _CodingKeys.WorkingOrderKeys.self, forKey: .workingOrder)
            self.identifier = try container.decode(IG.Deal.Identifier.self, forKey: .identifier)
            self.date = try container.decode(Date.self, forKey: .date, with: DateFormatter.iso8601Broad)
            self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
            self.currencyCode = try container.decode(Currency.Code.self, forKey: .currencyCode)
            self.direction = try container.decode(IG.Deal.Direction.self, forKey: .direction)
            self.type = try container.decode(API.WorkingOrder.Kind.self, forKey: .type)
            self.size = try container.decode(Decimal64.self, forKey: .size)
            self.level = try container.decode(Decimal64.self, forKey: .level)
            self.limit = try container.decodeIfPresent(IG.Deal.Limit.self, forLevelKey: nil, distanceKey: .limitDistance)
            self.stop = try container.decodeIfPresent(IG.Deal.Stop.self, forLevelKey: nil, distanceKey: .stopDistance, riskKey: (.isStopGuaranteed, .stopRiskPremium), trailingKey: (nil, nil, nil))
            self.isDirectlyAccessingMarket = try container.decode(Bool.self, forKey: .isDirectlyAccessingMarket)
            self.expiration = try {
                switch $0 {
                case Self.Expiration.CodingKeys.tillCancelled.rawValue: return .tillCancelled
                case Self.Expiration.CodingKeys.tillDate.rawValue: return .tillDate(try container.decode(Date.self, forKey: .expirationDate, with: DateFormatter.iso8601NoSeconds))
                default: throw DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: "The working order expiration '\($0)' couldn't be processed")
                }
            }(try container.decode(String.self, forKey: .expiration))
        }
        
        private enum _CodingKeys: String, CodingKey {
            case workingOrder = "workingOrderData"
            case market = "marketData"
            
            enum WorkingOrderKeys: String, CodingKey {
                case identifier = "dealId"
                case date = "createdDateUTC"
                case epic, currencyCode, direction
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
