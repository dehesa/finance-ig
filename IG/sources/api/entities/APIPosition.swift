import Foundation
import Decimals

extension API {
    /// Open position data.
    public struct Position: Identifiable {
        /// Permanent deal reference for a confirmed trade.
        public let id: IG.Deal.Identifier
        /// Transient deal reference for an unconfirmed trade.
        public let reference: IG.Deal.Reference
        /// Date the position was created.
        public let date: Date
        /// Position currency ISO code.
        public let currencyCode: Currency.Code?
        /// Deal direction.
        public let direction: IG.Deal.Direction
        /// Size of the contract.
        public let contractSize: Decimal64
        /// Deal size.
        public let size: Decimal64
        /// Level (instrument price) at which the position was openend.
        public let level: Decimal64
        /// The level (i.e. instrument's price) at which the user is happy to "take profit".
        public let limitLevel: Decimal64?
        /// The level (i.e. instrument's price) at which the user doesn't want to incur more losses.
        public let stop: (level: Decimal64, risk: IG.Deal.Stop.RiskData, trailing: IG.Deal.Stop.TrailingData)?
        /// The market basic information and current state (i.e. snapshot).
        public let market: API.Node.Market
    }
}

// MARK: -

extension API.Position: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.market = try container.decode(API.Node.Market.self, forKey: .market)
        
        let nestedContainer = try container.nestedContainer(keyedBy: _Keys._NestedKeys.self, forKey: .position)
        self.id = try nestedContainer.decode(IG.Deal.Identifier.self, forKey: .identifier)
        self.reference = try nestedContainer.decode(IG.Deal.Reference.self, forKey: .reference)
        self.date = try nestedContainer.decode(Date.self, forKey: .date, with: DateFormatter.iso8601Broad)
        self.currencyCode = try nestedContainer.decodeIfPresent(Currency.Code.self, forKey: .currencyCode)
        self.direction = try nestedContainer.decode(IG.Deal.Direction.self, forKey: .direction)
        self.contractSize = try nestedContainer.decode(Decimal64.self, forKey: .contractSize)
        self.size = try nestedContainer.decode(Decimal64.self, forKey: .size)
        self.level = try nestedContainer.decode(Decimal64.self, forKey: .level)
        self.limitLevel = try nestedContainer.decodeIfPresent(Decimal64.self, forKey: .limitLevel)
        
        if let stopLevel = try nestedContainer.decodeIfPresent(Decimal64.self, forKey: .stopLevel) {
            let (risk, trailing): (IG.Deal.Stop.RiskData, IG.Deal.Stop.TrailingData)
            
            switch (try nestedContainer.decode(Bool.self, forKey: .isStopGuaranteed), try nestedContainer.decodeIfPresent(Decimal64.self, forKey: .stopRiskPremium)) {
            case (false, _): risk = .exposed
            case (true, let p?): risk = .limited(premium: p)
            case (true, .none): throw DecodingError.dataCorruptedError(forKey: .stopRiskPremium, in: nestedContainer, debugDescription: "Risk premium value not found.")
            }
            
            switch (try nestedContainer.decodeIfPresent(Decimal64.self, forKey: .stopTrailingDistance), try nestedContainer.decodeIfPresent(Decimal64.self, forKey: .stopTrailingIncrement)) {
            case (.none, .none): trailing = .static
            case (let d?, let i?): trailing = .dynamic(distance: d, increment: i)
            default: throw DecodingError.dataCorruptedError(forKey: .stopTrailingDistance, in: nestedContainer, debugDescription: "Invalid trailing distance or increment.")
            }
            
            self.stop = (stopLevel, risk, trailing)
        } else { self.stop = nil }
    }
    
    private enum _Keys: String, CodingKey {
        case position, market
        
        enum _NestedKeys: String, CodingKey {
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
