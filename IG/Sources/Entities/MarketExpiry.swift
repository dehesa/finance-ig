import Foundation

extension IG.Market {
    /// The point when a trading position automatically closes is known as the expiry date (or expiration date).
    ///
    /// Expiry dates can vary from product to product. Spread bets, for example, always have a fixed expiry date. CFDs do not, unless they are on futures, digital 100s or options.
    public enum Expiry: ExpressibleByNilLiteral, Hashable, CustomDebugStringConvertible {
        /// DFBs (i.e. "Daily Funded Bets") run for as long as you choose to keep them open, with a default expiry some way off in the future.
        ///
        /// The cost of maintaining your DFB position is levied on your account each day: hence daily funded bet. You would generally use a daily funded bet to speculate on short-term market movements.
        case dailyFunded
        /// Forward bets will expire after a set period; instead of paying each day to keep the position open, the entire cost is taken into account in the spread.
        case forward(Date)
        /// No expiration date required.
        case none
        
        public init(nilLiteral: ()) {
            self = .none
        }
        
        public var debugDescription: String {
            switch self {
            case .none: return IG.DebugDescription.Symbol.nil
            case .dailyFunded: return "Daily funded"
            case .forward(let date): return IG.Formatter.timestampBroad.string(from: date)
            }
        }
    }
}

extension IG.Market.Expiry: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard !container.decodeNil() else { self = .none; return }
        
        let string = try container.decode(String.self)
        switch string {
        case _CodingKeys.none.rawValue:
            self = .none
        case _CodingKeys.dfb.rawValue, _CodingKeys.dfb.rawValue.lowercased():
            self = .dailyFunded
        default:
            if let date = IG.Formatter.dateDenormal.date(from: string) {
                self = .forward(date)
            } else if let date = IG.Formatter.dateDenormalBroad.date(from: string) {
                self = .forward(date.lastDayOfMonth)
            } else if let date = IG.Formatter.iso8601Broad.date(from: string) {
                self = .forward(date)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Market expiry couldn't be inferred from date: \(string)")
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode(_CodingKeys.none.rawValue)
        case .dailyFunded:
            try container.encode(_CodingKeys.dfb.rawValue)
        case .forward(let date):
            let formatter = (date.isLastDayOfMonth) ? IG.Formatter.dateDenormalBroad : IG.Formatter.dateDenormal
            try container.encode(formatter.string(from: date))
        }
    }
    
    private enum _CodingKeys: String, CodingKey {
        case dfb = "DFB"
        case none = "-"
    }
}

