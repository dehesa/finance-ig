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
    public func get(identifier: API.Position.Identifier) -> SignalProducer<API.Position,API.Error> {
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
        public let identifier: Self.Identifier
        /// Transient deal reference for an unconfirmed trade.
        public let reference: Self.Reference
        /// Date the position was created.
        public let date: Date
        
        /// Position currency ISO code.
        public let currency: Currency
        /// Size of the contract.
        public let contractSize: Double
        /// Deal size.
        public let size: Double
        /// Level (instrument price) at which the position was openend.
        public let level: Double
        /// Deal direction.
        public let direction: Self.Direction
        /// The level (i.e. instrument's price) at which the user is happy to "take profit".
        public let limit: Double?
        /// The level (i.e. instrument's price) at which the user doesn't want to incur more losses.
        public let stop: Self.Stop?
        
        /// The market basic information and current state (i.e. snapshot).
        public let market: API.Node.Market
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.market = try container.decode(API.Node.Market.self, forKey: .market)
            
            let nestedContainer = try container.nestedContainer(keyedBy: Self.CodingKeys.PositionKeys.self, forKey: .position)
            self.identifier = try nestedContainer.decode(Self.Identifier.self, forKey: .identifier)
            self.reference = try nestedContainer.decode(Self.Reference.self, forKey: .reference)
            self.date = try nestedContainer.decode(Date.self, forKey: .date, with: API.DateFormatter.iso8601NoTimezone)
            
            self.currency = try nestedContainer.decode(Currency.self, forKey: .currency)
            self.contractSize = try nestedContainer.decode(Double.self, forKey: .contractSize)
            self.size = try nestedContainer.decode(Double.self, forKey: .size)
            
            self.level = try nestedContainer.decode(Double.self, forKey: .level)
            self.direction = try nestedContainer.decode(Self.Direction.self, forKey: .direction)
            self.limit = try nestedContainer.decodeIfPresent(Double.self, forKey: .limitLevel)
            
            if let stopLevel = try nestedContainer.decodeIfPresent(Double.self, forKey: .stopLevel) {
                let risk: Self.Stop.Risk
                if try nestedContainer.decode(Bool.self, forKey: .isGuaranteedStop) {
                    let premium = try nestedContainer.decodeIfPresent(Double.self, forKey: .limitedRiskPremium)
                    risk = .limited(premium: premium)
                } else {
                    risk = .exposed
                }
                self.stop = .position(level: stopLevel, risk: risk)
            } else if let trailingDistance = try nestedContainer.decodeIfPresent(Double.self, forKey: .stopTrailingDistance),
               let trailingStep = try nestedContainer.decodeIfPresent(Double.self, forKey: .stopTrailingStep) {
                self.stop = .trailing(distance: trailingDistance, increment: trailingStep)
            } else {
                self.stop = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case position
            case market
            
            enum PositionKeys: String, CodingKey {
                case identifier = "dealId"
                case reference = "dealReference"
                case date = "createdDateUTC"
                case currency, contractSize, size
                case level, direction
                case limitLevel, stopLevel
                case isGuaranteedStop = "controlledRisk"
                case limitedRiskPremium
                case stopTrailingDistance = "trailingStopDistance"
                case stopTrailingStep = "trailingStep"
            }
        }
    }
}
