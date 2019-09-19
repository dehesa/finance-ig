import Foundation

/// Namespace for market information.
public enum Market {
    /// An epic represents a unique tradeable market.
    public struct Epic: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError(#"The market epic "\#(value)" is not in a valid format"#) }
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self.validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init?(_ description: String) {
            self.init(rawValue: description)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard Self.validate(rawValue) else {
                let reason = #"The market epic being decoded "\#(rawValue)" doesn't conform to the validation function"#
                throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
            }
            self.rawValue = rawValue
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        public var description: String {
            return self.rawValue
        }
    }
}

extension IG.Market.Epic {
    /// Returns a Boolean indicating whether the raw value can represent a market epic.
    private static func validate(_ value: String) -> Bool {
        let allowedRange = 6...30
        return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
    }
    
    /// The allowed character set for epics.
    ///
    /// It is used on validation.
    private static let allowedSet: CharacterSet = {
        var result = CharacterSet(arrayLiteral: ".", "_")
        result.formUnion(CharacterSet.lowercaseANSI)
        result.formUnion(CharacterSet.uppercaseANSI)
        result.formUnion(CharacterSet.decimalDigits)
        return result
    }()
}

extension IG.Market {
    /// The point when a trading position automatically closes is known as the expiry date (or expiration date).
    ///
    /// Expiry dates can vary from product to product. Spread bets, for example, always have a fixed expiry date. CFDs do not, unless they are on futures, digital 100s or options.
    public enum Expiry: ExpressibleByNilLiteral, Hashable, Codable, CustomDebugStringConvertible {
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
                if let date = IG.API.Formatter.dayMonthYear.date(from: string) {
                    self = .forward(date)
                } else if let date = IG.API.Formatter.monthYear.date(from: string) {
                    self = .forward(date.lastDayOfMonth)
                } else if let date = IG.API.Formatter.iso8601.date(from: string) {
                    self = .forward(date)
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: IG.API.Formatter.dayMonthYear.parseErrorLine(date: string))
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
                let formatter = (date.isLastDayOfMonth) ? IG.API.Formatter.monthYear : IG.API.Formatter.dayMonthYear
                try container.encode(formatter.string(from: date))
            }
        }
        
        public var debugDescription: String {
            switch self {
            case .none: return IG.DebugDescription.Symbol.nil
            case .dailyFunded: return "Daily funded"
            case .forward(let date): return IG.Formatter.date(.yearMonthDay, time: .hoursMinutes, localize: false).string(from: date)
            }
        }
    }
}

extension IG.Market.Expiry {
    private enum CodingKeys: String, CodingKey {
        case dfb = "DFB"
        case none = "-"
    }
}
