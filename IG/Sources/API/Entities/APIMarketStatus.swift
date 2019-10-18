import Foundation

extension IG.API.Market {
    /// The current status of the market.
    public enum Status: String, Codable {
        /// The market is open for trading.
        case tradeable = "TRADEABLE"
        /// The market is closed for the moment. Look at the market's opening hours for further information.
        case closed = "CLOSED"
        case editsOnly = "EDITS_ONLY"
        case onAuction = "ON_AUCTION"
        case onAuctionNoEdits = "ON_AUCTION_NO_EDITS"
        case offline = "OFFLINE"
        /// The market is suspended for trading temporarily.
        case suspended = "SUSPENDED"
    }
}

extension IG.API.Market {
    /// Market's price at a snapshot's time.
    public struct Price {
        /// The price being offered (to buy an asset).
        public let bid: Decimal?
        /// The price being asked (to sell an asset).
        public let ask: Decimal?
        /// Lowest price of the day.
        public let lowest: Decimal
        /// Highest price of the day.
        public let highest: Decimal
        /// Net and percentage change price on that day.
        public let change: (net: Decimal, percentage: Decimal)

        public init?(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.bid = try container.decodeIfPresent(Decimal.self, forKey: .bid)
            self.ask = try container.decodeIfPresent(Decimal.self, forKey: .ask)
            let lowest = try container.decodeIfPresent(Decimal.self, forKey: .lowest)
            let highest = try container.decodeIfPresent(Decimal.self, forKey: .highest)
            guard case .some = self.bid, case .some = self.ask,
                  case .some(let low) = lowest, case .some(let high) = highest else {
                    return nil
            }
            self.lowest = low
            self.highest = high
            self.change = (try container.decode(Decimal.self, forKey: .netChange),
                           try container.decode(Decimal.self, forKey: .percentageChange))
        }

        private enum CodingKeys: String, CodingKey {
            case bid, ask = "offer"
            case lowest = "low"
            case highest = "high"
            case netChange, percentageChange
        }

        /// The middle price between the *bid* and the *ask* price.
        public var mid: Decimal? {
            guard case .some(let bid) = self.bid,
                  case .some(let ask) = self.ask else { return nil }
            return bid + 0.5 * (ask - bid)
        }
    }
}
