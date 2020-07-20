import Decimals

extension API {
    /// Working order awaiting for its trigger to be met.
    public struct WorkingOrder {
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
        public let limitDistance: Decimal64?
        /// The distance from `level` at which the stop will be set once the order is fulfilled.
        public let stop: (distance: Decimal64, risk: IG.Deal.Stop.Risk)?
        /// Indicates whether the working order directly directly interac with the order book of an exchange.
        public let isDirectlyAccessingMarket: Bool
        /// Indicates when the working order expires if its triggers hasn't been met.
        public let expiration: Self.Expiration
        /// The market basic information and snapshot.
        public let market: API.Node.Market
    }
}


extension API.WorkingOrder {
    /// Working order type.
    public enum Kind {
        /// An instruction to deal if the price moves to a more favourable level.
        ///
        /// This is an order to open a position by buying when the market reaches a lower level than the current price, or selling short when the market hits a higher level than the current price.
        /// This is suitable if you think the market price will **change direction** when it hits a certain level.
        case limit
        /// This is an order to buy when the market hits a higher level than the current price, or sell when the market hits a lower level than the current price.
        /// This is suitable if you think the market will continue **moving in the same direction** once it hits a certain level.
        case stop
    }

    /// Describes when the working order will expire.
    public enum Expiration {
        /// The order remains in place till it is explicitly cancelled.
        case tillCancelled
        /// The order remains in place till it is fulfill or the associated date is reached.
        case tillDate(Date)
    }
}

// MARK: -

extension API.WorkingOrder: Decodable {
    public init(from decoder: Decoder) throws {
        let topContainer = try decoder.container(keyedBy: _Keys.self)
        self.market = try topContainer.decode(API.Node.Market.self, forKey: .market)
        
        let container = try topContainer.nestedContainer(keyedBy: _Keys._NestedKeys.self, forKey: .workingOrder)
        self.identifier = try container.decode(IG.Deal.Identifier.self, forKey: .identifier)
        self.date = try container.decode(Date.self, forKey: .date, with: DateFormatter.iso8601Broad)
        self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
        self.currencyCode = try container.decode(Currency.Code.self, forKey: .currencyCode)
        self.direction = try container.decode(IG.Deal.Direction.self, forKey: .direction)
        self.type = try container.decode(API.WorkingOrder.Kind.self, forKey: .type)
        self.size = try container.decode(Decimal64.self, forKey: .size)
        self.level = try container.decode(Decimal64.self, forKey: .level)
        self.limitDistance = try container.decodeIfPresent(Decimal64.self, forKey: .limitDistance)
        
        if let distance = try container.decodeIfPresent(Decimal64.self, forKey: .stopDistance) {
            let risk: IG.Deal.Stop.Risk = try container.decode(Bool.self, forKey: .isStopGuaranteed) ? .limited : .exposed
            self.stop = (distance, risk)
        } else { self.stop = nil }
        
        self.isDirectlyAccessingMarket = try container.decode(Bool.self, forKey: .isDirectlyAccessingMarket)
        
        switch try container.decode(String.self, forKey: .expiration) {
        case "GOOD_TILL_CANCELLED": self.expiration = .tillCancelled
        case "GOOD_TILL_DATE": self.expiration = .tillDate(try container.decode(Date.self, forKey: .expirationDate, with: DateFormatter.iso8601NoSeconds))
        case let value: throw DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: "Invalid working order expiration '\(value)'.")
        }
    }
    
    private enum _Keys: String, CodingKey {
        case workingOrder = "workingOrderData"
        case market = "marketData"
        
        enum _NestedKeys: String, CodingKey {
            case identifier = "dealId"
            case date = "createdDateUTC"
            case epic, currencyCode, direction
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

extension API.WorkingOrder.Kind: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case _Values.limit: self = .limit
        case _Values.stop: self = .stop
        case let value: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid working order type '\(value)'.")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .limit: try container.encode(_Values.limit)
        case .stop: try container.encode(_Values.stop)
        }
    }
    
    private enum _Values {
        static var limit: String { "LIMIT" }
        static var stop: String { "STOP" }
    }
}
