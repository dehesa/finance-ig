import ReactiveSwift
import Foundation

extension API.Request.Positions {
    
    // MARK: GET /positions
    
    /// Returns all open positions for the active account.
    ///
    /// A position is a running bet, which may be long (buy) or short (sell).
    public func getAll() -> SignalProducer<[API.Position],API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "positions", version: 2, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperList) in w.positions }
    }
    
    // MARK: GET /positions/{dealId}
    
    /// Returns an open position for the active account by deal identifier.
    /// - parameter identifier: Targeted permanent deal reference for an already confirmed trade.
    public func get(identifier: IG.Deal.Identifier) -> SignalProducer<API.Position,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "positions/\(identifier.rawValue)", version: 2, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to API positions.
    public struct Positions {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        internal unowned let api: API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        init(api: API) {
            self.api = api
        }
    }
}

// MARK: Response Entities

extension API.Request.Positions {
    private struct WrapperList: Decodable {
        let positions: [API.Position]
    }
}

extension API {
    /// Open position data.
    public struct Position: Decodable {
        /// Permanent deal reference for a confirmed trade.
        public let identifier: IG.Deal.Identifier
        /// Transient deal reference for an unconfirmed trade.
        public let reference: IG.Deal.Reference
        /// Date the position was created.
        public let date: Date
        /// Position currency ISO code.
        public let currency: Currency.Code
        /// Deal direction.
        public let direction: IG.Deal.Direction
        /// Size of the contract.
        public let contractSize: Decimal
        /// Deal size.
        public let size: Decimal
        /// Level (instrument price) at which the position was openend.
        public let level: Decimal
        /// The level (i.e. instrument's price) at which the user is happy to "take profit".
        public let limit: IG.Deal.Limit?
        /// The level (i.e. instrument's price) at which the user doesn't want to incur more losses.
        public let stop: IG.Deal.Stop?
        /// The market basic information and current state (i.e. snapshot).
        public let market: API.Node.Market
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.market = try container.decode(API.Node.Market.self, forKey: .market)
            
            let nestedContainer = try container.nestedContainer(keyedBy: Self.CodingKeys.PositionKeys.self, forKey: .position)
            self.identifier = try nestedContainer.decode(IG.Deal.Identifier.self, forKey: .identifier)
            self.reference = try nestedContainer.decode(IG.Deal.Reference.self, forKey: .reference)
            self.date = try nestedContainer.decode(Date.self, forKey: .date, with: API.Formatter.iso8601)
            self.currency = try nestedContainer.decode(Currency.Code.self, forKey: .currency)
            self.direction = try nestedContainer.decode(IG.Deal.Direction.self, forKey: .direction)
            self.contractSize = try nestedContainer.decode(Decimal.self, forKey: .contractSize)
            self.size = try nestedContainer.decode(Decimal.self, forKey: .size)
            self.level = try nestedContainer.decode(Decimal.self, forKey: .level)
            self.limit = try nestedContainer.decodeIfPresent(IG.Deal.Limit.self, forLevelKey: .limitLevel, distanceKey: nil, referencing: (self.direction, self.level))
            self.stop = try nestedContainer.decodeIfPresent(IG.Deal.Stop.self, forLevelKey: .stopLevel, distanceKey: nil, riskKey: (.isStopGuaranteed, .stopRiskPremium), trailingKey: (nil, .stopTrailingDistance, .stopTrailingIncrement), referencing: (self.direction, self.level))
        }
        
        private enum CodingKeys: String, CodingKey {
            case position
            case market
            
            enum PositionKeys: String, CodingKey {
                case identifier = "dealId"
                case reference = "dealReference"
                case date = "createdDateUTC"
                case currency, contractSize, size
                case direction, level
                case limitLevel, stopLevel
                case isStopGuaranteed = "controlledRisk"
                case stopRiskPremium = "limitedRiskPremium"
                case stopTrailingDistance = "trailingStopDistance"
                case stopTrailingIncrement = "trailingStep"
            }
        }
    }
}
