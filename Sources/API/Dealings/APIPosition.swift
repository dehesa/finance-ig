import ReactiveSwift
import Result
import Foundation

extension API {
    /// Returns all open positions for the active account.
    ///
    /// A position is a running bet, which may be long (buy) or short (sell).
    public func positions() -> SignalProducer<[API.Response.Position],API.Error> {
        return self.makeRequest(.get, "positions", version: 2, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.PositionListWrapper) in w.positions }
    }
    
    /// Returns an open position for the active account by deal identifier.
    ///
    /// A position is a running bet, which may be long (buy) or short (sell).
    /// - parameter id: Targeted deal identifier.
    public func position(id: String) -> SignalProducer<API.Response.Position,API.Error> {
        return self.makeRequest(.get, "positions/\(id)", version: 2, credentials: true, queries: {
                guard !id.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "Position retrieval failed! The deal identifier cannot be empty.") }
                return []
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
    }
}

extension API.Response {
    /// Wrapper around a list of positions.
    fileprivate struct PositionListWrapper: Decodable {
        let positions: [Position]
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
    
    /// Open position data.
    public struct Position: Decodable {
        /// Permanent deal reference for a confirmed trade.
        public let identifier: String
        /// Transient deal reference for an unconfirmed trade.
        public let reference: String
        /// Date the position was opened.
        public let date: Date
        /// Position currency ISO code.
        public let currency: String
        /// Size of the contract.
        ///
        /// How many times `size` has been agreed (a.k.a. `contractSize` * `size`).
        public let contractSize: Double
        /// Deal size.
        public let size: Double
        /// Deal direction.
        public let direction: API.Position.Direction
        /// Level (instrument price) at which the position was openend.
        public let level: Double
        /// The level boundaries.
        public let boundaries: Boundaries
        /// Boolean indicating whether the position is risk controlled.
        public let isRiskControlled: Bool
        // let limitedRiskPremium: ???  // TODO: limitedRiskPremium
        /// The market basic information and snapshot.
        public let market: API.Response.Watchlist.Market
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.market = try container.decode(API.Response.Watchlist.Market.self, forKey: .market)
            
            let nestedContainer = try container.nestedContainer(keyedBy: CodingKeys.NestedKeys.self, forKey: .info)
            self.identifier = try nestedContainer.decode(String.self, forKey: .identifier)
            self.reference = try nestedContainer.decode(String.self, forKey: .reference)
            self.date = try nestedContainer.decode(Date.self, forKey: .date, with: API.DateFormatter.iso8601NoTimezone)
            self.currency = try nestedContainer.decode(String.self, forKey: .currency)
            
            self.contractSize = try nestedContainer.decode(Double.self, forKey: .contractSize)
            self.size = try nestedContainer.decode(Double.self, forKey: .size)
            self.direction = try nestedContainer.decode(API.Position.Direction.self, forKey: .direction)
            self.level = try nestedContainer.decode(Double.self, forKey: .level)
            
            let stop: API.Position.Boundary.Stop?
            if let stopLevel = try nestedContainer.decodeIfPresent(Double.self, forKey: .stopLevel) {
                stop = .position(stopLevel)
            } else if let trailingDistance = try nestedContainer.decodeIfPresent(Double.self, forKey: .stopTrailingDistance),
                let trailingStep = try nestedContainer.decodeIfPresent(Double.self, forKey: .stopTrailingStep) {
                stop = .trailing(distance: trailingDistance, increment: trailingStep)
            } else {
                stop = nil
            }
            
            let limit = try nestedContainer.decodeIfPresent(Double.self, forKey: .limit)
            self.boundaries = Boundaries(limit: limit.map { .position($0) }, stop: stop)
            self.isRiskControlled = try nestedContainer.decode(Bool.self, forKey: .isRiskControlled)
        }
        
        private enum CodingKeys: String, CodingKey {
            case info = "position"
            case market
            
            enum NestedKeys: String, CodingKey {
                case identifier = "dealId"
                case reference = "dealReference"
                case date = "createdDateUTC"
                case currency
                case direction
                case size
                case contractSize
                case level
                case limit = "limitLevel"
                case stopLevel
                case stopTrailingStep = "trailingStep"
                case stopTrailingDistance = "trailingStopDistance"
                case isRiskControlled = "controlledRisk"
                // case limitedRiskPremium
            }
        }
        
        /// Reflect the boundaries for a deal level.
        public struct Boundaries: APIPositionBoundaries {
            public let limit: API.Position.Boundary.Limit?
            public let stop: API.Position.Boundary.Stop?
            
            /// Designated initializer.
            public init(limit: API.Position.Boundary.Limit?, stop: API.Position.Boundary.Stop?) {
                self.limit = limit
                self.stop = stop
            }
        }
    }
}
