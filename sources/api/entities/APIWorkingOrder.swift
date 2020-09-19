import Decimals
import Foundation

extension API {
    /// Working order awaiting for its trigger to be met.
    public struct WorkingOrder: Identifiable {
        /// Permanent deal reference for a confirmed trade.
        public let id: IG.Deal.Identifier
        /// Date when the order was created.
        public let date: Date
        /// Instrument epic identifier.
        public let epic: IG.Market.Epic
        /// Currency ISO code.
        public let currency: Currency.Code
        /// The working order type.
        public let type: IG.Deal.WorkingOrder
        /// Indicates when the working order expires if its triggers hasn't been met.
        public let expiration: IG.Deal.WorkingOrder.Expiration
        /// Deal direction.
        public let direction: IG.Deal.Direction
        /// Deal size.
        public let size: Decimal64
        /// Price at which to execute the trade.
        public let level: Decimal64
        /// The level/distance at which the user is happy to take profit.
        public let limitDistance: Decimal64?
        /// The distance from `level` at which the stop will be set once the order is fulfilled.
        public let stop: (distance: Decimal64, risk: IG.Deal.Stop.Risk)?
        /// Indicates whether the working order directly directly interac with the order book of an exchange.
        public let isDirectlyAccessingMarket: Bool
        /// The market basic information and snapshot.
        public let market: API.Node.Market
    }
}

// MARK: -

extension API.WorkingOrder: Decodable {
    public init(from decoder: Decoder) throws {
        let topContainer = try decoder.container(keyedBy: _Keys.self)
        self.market = try topContainer.decode(API.Node.Market.self, forKey: .market)
        
        let container = try topContainer.nestedContainer(keyedBy: _Keys._NestedKeys.self, forKey: .workingOrder)
        self.id = try container.decode(IG.Deal.Identifier.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date, with: DateFormatter.iso8601Broad)
        self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
        self.currency = try container.decode(Currency.Code.self, forKey: .currency)
        self.type = try container.decode(IG.Deal.WorkingOrder.self, forKey: .type)
        
        switch try container.decode(String.self, forKey: .expiration) {
        case "GOOD_TILL_CANCELLED": self.expiration = .tillCancelled
        case "GOOD_TILL_DATE": self.expiration = .tillDate(try container.decode(Date.self, forKey: .expirationDate, with: DateFormatter.iso8601NoSeconds))
        case let value: throw DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: "Invalid working order expiration '\(value)'.")
        }
        
        self.direction = try container.decode(IG.Deal.Direction.self, forKey: .direction)
        self.size = try container.decode(Decimal64.self, forKey: .size)
        self.level = try container.decode(Decimal64.self, forKey: .level)
        self.limitDistance = try container.decodeIfPresent(Decimal64.self, forKey: .limitDistance)
        
        if let distance = try container.decodeIfPresent(Decimal64.self, forKey: .stopDistance) {
            let risk: IG.Deal.Stop.Risk = try container.decode(Bool.self, forKey: .isStopGuaranteed) ? .limited : .exposed
            self.stop = (distance, risk)
        } else { self.stop = nil }
        
        self.isDirectlyAccessingMarket = try container.decode(Bool.self, forKey: .isDirectlyAccessingMarket)
        
        
    }
    
    private enum _Keys: String, CodingKey {
        case workingOrder = "workingOrderData"
        case market = "marketData"
        
        enum _NestedKeys: String, CodingKey {
            case id = "dealId"
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
            case isDirectlyAccessingMarket = "dma"
            case expiration = "timeInForce"
            case expirationDate = "goodTillDateISO"
        }
    }
}
