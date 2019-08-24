import Foundation

/// Namespace for market information.
public enum Market {
    /// An epic represents a unique tradeable market.
    public struct Epic: RawRepresentable, Codable, ExpressibleByStringLiteral, Hashable, CustomStringConvertible {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError("The epic couldn't be identified or is not in the correct format.") }
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self.validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard Self.validate(rawValue) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "The given string doesn't conform to the regex pattern.")
            }
            self.rawValue = rawValue
        }
        
        public var description: String {
            return self.rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        private static func validate(_ value: String) -> Bool {
            let allowedRange = 6...30
            return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
        }
        
        /// The allowed character set for epics.
        ///
        /// It is used on validation.
        private static let allowedSet: CharacterSet = {
            var result = CharacterSet(arrayLiteral: ".", "_")
            result.formUnion(CharacterSet.IG.lowercaseANSI)
            result.formUnion(CharacterSet.IG.uppercaseANSI)
            result.formUnion(CharacterSet.decimalDigits)
            return result
        }()
    }
}

extension Market {
    /// The underlying financial instrument being traded in the market.
    public enum Instrument {
        /// Instrument related entities.
        public enum Kind: Decodable {
            /// A binary allows you to take a view on whether a specific outcome will or won't occur.
            ///
            /// For example, Will Wall Street be up at the close of the day?
            /// - If the answer is 'yes', the binary settles at 100.
            /// - If the answer is 'no', the binary settles at 0.
            ///
            /// Your profit or loss is the difference between 100 (if the event occurs) or zero (if the event doesn't occur) and the level at which you 'bought' or 'sold'. Binary prices can be extremely volatile even when the underlying market is relatively static. A small movement in the underlying can make all the difference between the binary settling at 0 or 100.
            case binary
            case bungee(Self.Bungee)
            /// Commodities are hard assets ranging from wheat to gold to oil.
            case commodities
            /// Currencies are medium of exchange.
            case currencies
            /// An index is an statistical measure of change in a securities market.
            case indices
            /// An option is a contract which gives the buyer the right, but not the obligation, to guy or sell an underlying asset or instrument at a specified strike price prior to or on a specified date, depending on the form of the option.
            case options(Self.Options)
            case rates
            case sectors
            /// Shares are unit of ownership interest in a corporation or financial asset that provide for an equal distribution in any profits, if any are declared, in the form of dividends.
            case shares
            case sprintMarket
            case testMarket
            case unknown
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let string = try container.decode(String.self)
                switch string {
                case "BINARY": self = .binary
                case "COMMODITIES": self = .commodities
                case "CURRENCIES": self = .currencies
                case "INDICES": self = .indices
                case "OPT_COMMODITIES": self = .options(.commodities)
                case "OPT_CURRENCIES": self = .options(.currencies)
                case "OPT_INDICES": self = .options(.indices)
                case "OPT_RATES": self = .options(.rates)
                case "OPT_SHARES": self = .options(.shares)
                case "RATES": self = .rates
                case "SECTORS": self = .sectors
                case "SHARES": self = .shares
                case "SPRINT_MARKET": self = .sprintMarket
                case "TEST_MARKET": self = .testMarket
                case "UNKNOWN": self = .unknown
                case "BUNGEE_CAPPED": self = .bungee(.capped)
                case "BUNGEE_COMMODITIES": self = .bungee(.commodities)
                case "BUNGEE_CURRENCIES": self = .bungee(.currencies)
                case "BUNGEE_INDICES": self = .bungee(.indices)
                default:
                    let message = #"The instrument type "\#(string)" couldn't be mapped to a proper type"#
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: message)
                }
            }
            
            public enum Bungee: String {
                case capped  = "BUNGEE_CAPPED"
                case commodities  = "BUNGEE_COMMODITIES"
                case currencies = "BUNGEE_CURRENCIES"
                case indices = "BUNGEE_INDICES"
            }
            
            public enum Options: String {
                case commodities = "OPT_COMMODITIES"
                case currencies = "OPT_CURRENCIES"
                case indices = "OPT_INDICES"
                case rates = "OPT_RATES"
                case shares = "OPT_SHARES"
            }
        }
    }
}

extension Market.Instrument {
    /// The point when a trading position automatically closes is known as the expiry date (or expiration date).
    ///
    /// Expiry dates can vary from product to product. Spread bets, for example, always have a fixed expiry date. CFDs do not, unless they are on futures, digital 100s or options.
    public enum Expiry: ExpressibleByNilLiteral, Codable, Equatable {
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
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            guard !container.decodeNil() else {
                self = .none; return
            }
            
            let string = try container.decode(String.self)
            switch string {
            case Self.CodingKeys.none.rawValue:
                self = .none
            case Self.CodingKeys.dfb.rawValue, Self.CodingKeys.dfb.rawValue.lowercased():
                self = .dailyFunded
            default:
                if let date = API.Formatter.dayMonthYear.date(from: string) {
                    self = .forward(date)
                } else if let date = API.Formatter.monthYear.date(from: string) {
                    self = .forward(date.lastDayOfMonth)
                } else if let date = API.Formatter.iso8601.date(from: string) {
                    self = .forward(date)
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: API.Formatter.dayMonthYear.parseErrorLine(date: string))
                }
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .none:
                try container.encode(Self.CodingKeys.none.rawValue)
            case .dailyFunded:
                try container.encode(Self.CodingKeys.dfb.rawValue)
            case .forward(let date):
                let formatter = (date.isLastDayOfMonth) ? API.Formatter.monthYear : API.Formatter.dayMonthYear
                try container.encode(formatter.string(from: date))
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case dfb = "DFB"
            case none = "-"
        }
    }
}
