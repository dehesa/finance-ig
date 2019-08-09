import Foundation

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
            
            self.change = (
                try container.decode(Decimal.self, forKey: .netChange),
                try container.decode(Decimal.self, forKey: .percentageChange)
            )
        }
        
        private enum CodingKeys: String, CodingKey {
            case bid, ask = "offer"
            case lowest = "low"
            case highest = "high"
            case netChange, percentageChange
        }
    }
}

extension API {
    /// Instrument related entities.
    public enum Instrument: String, Codable {
        /// A binary allows you to take a view on whether a specific outcome will or won't occur. For example, 'Will Wall Street be up at the close of the day?' If the answer is 'yes', the binary settles at 100. If the answer is 'no', the binary settles at 0. Your profit or loss is the difference between 100 (if the event occurs) or zero (if the event doesn't occur) and the level at which you 'bought' or 'sold'. Binary prices can be extremely volatile even when the underlying market is relatively static. A small movement in the underlying can make all the difference between the binary settling at 0 or 100.
        case binary = "BINARY"
        case bungeeCapped  = "BUNGEE_CAPPED"
        case bungeeCommodities  = "BUNGEE_COMMODITIES"
        case bungeeCurrencies = "BUNGEE_CURRENCIES"
        case bungeeIndices = "BUNGEE_INDICES"
        case commodities = "COMMODITIES"
        case currencies = "CURRENCIES"
        case indices = "INDICES"
        case optCommodities = "OPT_COMMODITIES"
        case optCurrencies = "OPT_CURRENCIES"
        case optIndices = "OPT_INDICES"
        case optRates = "OPT_RATES"
        case optShares = "OPT_SHARES"
        case rates = "RATES"
        case sectors = "SECTORS"
        case shares = "SHARES"
        case sprintMarket = "SPRINT_MARKET"
        case testMarket = "TEST_MARKET"
        case unknown = "UNKNOWN"
    }
}
