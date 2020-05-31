import Decimals

extension API.Market {
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

extension API.Market {
    /// Market's price at a snapshot's time.
    public struct Price {
        /// The price being offered (to buy an asset).
        public let bid: Decimal64?
        /// The price being asked (to sell an asset).
        public let ask: Decimal64?
        /// Lowest price of the day.
        public let lowest: Decimal64
        /// Highest price of the day.
        public let highest: Decimal64
        /// Net and percentage change price on that day.
        public let change: (net: Decimal64, percentage: Decimal64)

        public init?(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _CodingKeys.self)
            self.bid = try container.decodeIfPresent(Decimal64.self, forKey: .bid)
            self.ask = try container.decodeIfPresent(Decimal64.self, forKey: .ask)
            let lowest = try container.decodeIfPresent(Decimal64.self, forKey: .lowest)
            let highest = try container.decodeIfPresent(Decimal64.self, forKey: .highest)
            guard case .some = self.bid, case .some = self.ask,
                  case .some(let low) = lowest, case .some(let high) = highest else {
                    return nil
            }
            self.lowest = low
            self.highest = high
            self.change = (try container.decode(Decimal64.self, forKey: .netChange),
                           try container.decode(Decimal64.self, forKey: .percentageChange))
        }

        private enum _CodingKeys: String, CodingKey {
            case bid, ask = "offer"
            case lowest = "low"
            case highest = "high"
            case netChange, percentageChange
        }

        /// The middle price between the *bid* and the *ask* price.
        @_transparent public var mid: Decimal64? {
            guard let bid = self.bid, let ask = self.ask else { return nil }
            return bid + Decimal64(5, power: -1)! * (ask - bid)
        }
    }
}
