import Combine
import Foundation

extension IG.API.Request {
    /// List of endpoints related to API positions.
    public struct Positions {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        internal unowned let api: IG.API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        init(api: IG.API) {
            self.api = api
        }
    }
}

extension IG.API.Request.Positions {
    
    // MARK: GET /positions
    
    /// Returns all open positions for the active account.
    ///
    /// A position is a running bet, which may be long (buy) or short (sell).
    /// - returns: *Future* forwarding a list of open positions.
    public func getAll() -> IG.API.Future<[IG.API.Position]> {
        self.api.publisher
            .makeRequest(.get, "positions", version: 2, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (w: Self.WrapperList, _) in w.positions }
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /positions/{dealId}
    
    /// Returns an open position for the active account by deal identifier.
    /// - parameter identifier: Targeted permanent deal reference for an already confirmed trade.
    /// - returns: *Future* forwarding the targeted position.
    public func get(identifier: IG.Deal.Identifier) -> IG.API.Future<IG.API.Position> {
        self.api.publisher
            .makeRequest(.get, "positions/\(identifier.rawValue)", version: 2, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true))
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.API.Request.Positions {
    private struct WrapperList: Decodable {
        let positions: [IG.API.Position]
    }
}

extension IG.API {
    /// Open position data.
    public struct Position: Decodable {
        /// Permanent deal reference for a confirmed trade.
        public let identifier: IG.Deal.Identifier
        /// Transient deal reference for an unconfirmed trade.
        public let reference: IG.Deal.Reference
        /// Date the position was created.
        public let date: Date
        /// Position currency ISO code.
        public let currencyCode: IG.Currency.Code
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
        public let market: IG.API.Node.Market
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.market = try container.decode(IG.API.Node.Market.self, forKey: .market)
            
            let nestedContainer = try container.nestedContainer(keyedBy: Self.CodingKeys.PositionKeys.self, forKey: .position)
            self.identifier = try nestedContainer.decode(IG.Deal.Identifier.self, forKey: .identifier)
            self.reference = try nestedContainer.decode(IG.Deal.Reference.self, forKey: .reference)
            self.date = try nestedContainer.decode(Date.self, forKey: .date, with: IG.API.Formatter.iso8601Broad)
            self.currencyCode = try nestedContainer.decode(IG.Currency.Code.self, forKey: .currencyCode)
            self.direction = try nestedContainer.decode(IG.Deal.Direction.self, forKey: .direction)
            self.contractSize = try nestedContainer.decode(Decimal.self, forKey: .contractSize)
            self.size = try nestedContainer.decode(Decimal.self, forKey: .size)
            self.level = try nestedContainer.decode(Decimal.self, forKey: .level)
            self.limit = try nestedContainer.decodeIfPresent(IG.Deal.Limit.self, forLevelKey: .limitLevel, distanceKey: nil)
            self.stop = try nestedContainer.decodeIfPresent(IG.Deal.Stop.self, forLevelKey: .stopLevel, distanceKey: nil, riskKey: (.isStopGuaranteed, .stopRiskPremium), trailingKey: (nil, .stopTrailingDistance, .stopTrailingIncrement))
        }
        
        private enum CodingKeys: String, CodingKey {
            case position
            case market
            
            enum PositionKeys: String, CodingKey {
                case identifier = "dealId"
                case reference = "dealReference"
                case date = "createdDateUTC"
                case currencyCode = "currency"
                case contractSize, size
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

// MARK: - Functionality

extension IG.API.Position: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("deal ID", self.identifier)
        result.append("deal reference", self.reference)
        result.append("date", self.date, formatter: IG.Formatter.timestamp.deepCopy(timeZone: .current))
        result.append("epic", self.market.instrument.epic)
        result.append("currency", self.currencyCode)
        result.append("direction", self.direction)
        result.append("contract size", self.contractSize)
        result.append("size", self.size)
        result.append("level", self.level)
        result.append("limit", self.limit?.debugDescription)
        result.append("stop", self.stop?.debugDescription)
        return result.generate()
    }
}
