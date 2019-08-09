import Foundation

/// Namespace for commonly used value/class types related to deals.
public enum Deal {}

extension Deal {
    /// Position's permanent identifier.
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, Codable, CustomStringConvertible, Hashable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError(#"The deal identifier "\#(value)" is not in a valid format."#) }
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
                throw DecodingError.dataCorruptedError(in: container, debugDescription: #"The deal identifier being decoded "\#(rawValue)" doesn't conform to the validation function."#)
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
        
        /// Tests the given argument/rawValue for a matching instance.
        /// - parameter value: The future raw value of this instance.
        private static func validate(_ value: String) -> Bool {
            return (1...30).contains(value.count)
        }
    }
}

extension Deal {
    /// Transient deal identifier (for an unconfirmed trade).
    public struct Reference: RawRepresentable, ExpressibleByStringLiteral, Codable, CustomStringConvertible, Hashable {
        public let rawValue: String
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError(#"The deal reference "\#(value)" is not in a valid format."#) }
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
                throw DecodingError.dataCorruptedError(in: container, debugDescription: #"The deal reference being decoded "\#(rawValue)" doesn't conform to the validation function."#)
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
        
        /// The allowed character set used on validation.
        private static let allowedSet: CharacterSet = {
            var result = CharacterSet(arrayLiteral: "_", "-", #"\"#)
            result.formUnion(CharacterSet.IG.lowercaseANSI)
            result.formUnion(CharacterSet.IG.uppercaseANSI)
            result.formUnion(CharacterSet.decimalDigits)
            return result
        }()
        
        /// Tests the given argument/rawValue for a matching instance.
        /// - parameter value: The future raw value of this instance.
        private static func validate(_ value: String) -> Bool {
            let allowedRange = 1...30
            return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
        }
    }
}

extension Deal {
    /// Deal direction.
    public enum Direction: String, Equatable, Codable {
        /// Going "long"
        case buy = "BUY"
        /// Going "short"
        case sell = "SELL"
        
        /// Returns the opposite direction from the receiving direction.
        /// - returns: `.buy` if receiving is `.sell`, and `.sell` if receiving is `.buy`.
        public var oppossite: Direction {
            switch self {
            case .buy:  return .sell
            case .sell: return .buy
            }
        }
    }
}

extension Deal {
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
