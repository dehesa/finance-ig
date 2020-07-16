import Combine
import Foundation
import Decimals

extension API.Request.Deals {
    
    // MARK: GET /positions
    
    /// Returns all open positions for the active account.
    ///
    /// A position is a running bet, which may be long (buy) or short (sell).
    /// - returns: *Future* forwarding a list of open positions.
    public func getAll() -> AnyPublisher<[API.Position],IG.Error> {
        self.api.publisher
            .makeRequest(.get, "positions", version: 2, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(date: true)) { (w: _WrapperList, _) in w.positions }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /positions/{dealId}
    
    /// Returns an open position for the active account by deal identifier.
    /// - parameter identifier: Targeted permanent deal reference for an already confirmed trade.
    /// - returns: *Future* forwarding the targeted position.
    public func get(identifier: IG.Deal.Identifier) -> AnyPublisher<API.Position,IG.Error> {
        self.api.publisher
            .makeRequest(.get, "positions/\(identifier.rawValue)", version: 2, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(date: true))
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension API.Request.Deals {
    private struct _WrapperList: Decodable {
        let positions: [API.Position]
    }
}

extension API {
    /// Open position data.
    public struct Position: Decodable {
        /// Date the position was created.
        public let date: Date
        /// Permanent deal reference for a confirmed trade.
        public let identifier: IG.Deal.Identifier
        /// Transient deal reference for an unconfirmed trade.
        public let reference: IG.Deal.Reference
        /// Position currency ISO code.
        public let currencyCode: Currency.Code
        #warning("Make currencyCode optional for epics which are not forex")
        /// Deal direction.
        public let direction: IG.Deal.Direction
        /// Size of the contract.
        public let contractSize: Decimal64
        /// Deal size.
        public let size: Decimal64
        /// Level (instrument price) at which the position was openend.
        public let level: Decimal64
        /// The level (i.e. instrument's price) at which the user is happy to "take profit".
        public let limit: IG.Deal.Limit?
        /// The level (i.e. instrument's price) at which the user doesn't want to incur more losses.
        public let stop: IG.Deal.Stop?
        /// The market basic information and current state (i.e. snapshot).
        public let market: API.Node.Market
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _CodingKeys.self)
            self.market = try container.decode(API.Node.Market.self, forKey: .market)
            
            let nestedContainer = try container.nestedContainer(keyedBy: _CodingKeys.PositionKeys.self, forKey: .position)
            self.identifier = try nestedContainer.decode(IG.Deal.Identifier.self, forKey: .identifier)
            self.reference = try nestedContainer.decode(IG.Deal.Reference.self, forKey: .reference)
            self.date = try nestedContainer.decode(Date.self, forKey: .date, with: DateFormatter.iso8601Broad)
            self.currencyCode = try nestedContainer.decode(Currency.Code.self, forKey: .currencyCode)
            self.direction = try nestedContainer.decode(IG.Deal.Direction.self, forKey: .direction)
            self.contractSize = try nestedContainer.decode(Decimal64.self, forKey: .contractSize)
            self.size = try nestedContainer.decode(Decimal64.self, forKey: .size)
            self.level = try nestedContainer.decode(Decimal64.self, forKey: .level)
            self.limit = try nestedContainer.decodeIfPresent(IG.Deal.Limit.self, forLevelKey: .limitLevel, distanceKey: nil)
            self.stop = try nestedContainer.decodeIfPresent(IG.Deal.Stop.self, forLevelKey: .stopLevel, distanceKey: nil, riskKey: (.isStopGuaranteed, .stopRiskPremium), trailingKey: (nil, .stopTrailingDistance, .stopTrailingIncrement))
        }
        
        private enum _CodingKeys: String, CodingKey {
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
