import Foundation

extension API.Deal {
    /// Position's permanent identifier.
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, Codable, CustomStringConvertible, Hashable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError("The deal identifier couldn't be identified or is not in the correct format.") }
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
        
        /// Tests the given argument/rawValue for a matching instance.
        /// - parameter value: The future raw value of this instance.
        private static func validate(_ value: String) -> Bool {
            return (1...30).contains(value.count)
        }
    }
}

extension API.Deal {
    /// Transient deal identifier (for an unconfirmed trade).
    public struct Reference: RawRepresentable, ExpressibleByStringLiteral, Codable, CustomStringConvertible, Hashable {
        public let rawValue: String
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError("The deal reference couldn't be identified or is not in the correct format.") }
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

extension API.Deal {
    /// Deal direction.
    public enum Direction: String, Equatable, Codable {
        case buy = "BUY"
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

extension API.Deal {
    /// The limit at which the user is taking profit.
    public enum Limit {
        /// Specifies the limit as a given absolute level.
        /// - parameter level: The absolute level where the limit will be set.
        case position(level: Decimal)
        /// Relative limit over an undisclosed reference level.
        case distance(Decimal)
        
        /// Returns the absolute limit level.
        /// - parameter base: The deal  level.
        /// - parameter direction: The deal direction from which to mark the distance. `.buy` deals will have the limits higher than the reference levels, while `.sell` deals will have then lower.
        public func level(from reference: (base: Decimal, direction: API.Deal.Direction)? = nil) -> Decimal? {
            switch self {
            case .position(let level):
                return level
            case .distance(let distance):
                guard let (base, direction) = reference else { return nil }
                
                switch direction {
                case .buy:  return base + distance
                case .sell: return base - distance
                }
            }
        }
        
        /// Returns the distance from the base to the limit level.
        /// - parameter base: The deal  level.
        /// - parameter direction: The deal direction from which to mark the distance. `.buy` deals will have the limits higher than the reference levels, while `.sell` deals will have then lower.
        public func distance(from reference: (base: Decimal, direction: API.Deal.Direction)? = nil) -> Decimal? {
            switch self {
            case .distance(let distance):
                return distance
            case .position(let level):
                guard let (base, direction) = reference else { return nil }
                
                switch direction {
                case .buy:  return level - base
                case .sell: return base - level
                }
            }
        }
        
        /// Check whether the receiving limit is valid in reference to the given base level and direction.
        public func isValid(forBase base: Decimal, direction: API.Deal.Direction) -> Bool {
            switch self {
            case .position(let level):
                switch direction {
                case .buy:  return level > base
                case .sell: return level < base
                }
            case .distance(let distance):
                return distance.isNormal && (distance.sign == .plus)
            }
        }
    }
}

extension API.Deal {
    /// The level/price at which the user doesn't want to incur more lose.
    public struct Stop {
        /// The type of stop (whether absolute level or relative distance).
        public let type: Self.Kind
        /// The type of risk the user is assuming when the stop is hit.
        public let risk: Self.Risk
        ///  Whether the stop is a "trailing stop" or a "static stop".
        public let trailing: Self.Trailing
        
        /// Designated initializer.
        /// - parameter risk: The risk exposed when exercising the stop loss.
        internal init(_ type: Self.Kind, risk: Self.Risk, trailing: Self.Trailing) {
            self.type = type
            self.risk = risk
            self.trailing = trailing
        }
        
        public var isTrailing: Bool {
            switch self.trailing {
            case .static:  return false
            case .dynamic: return true
            }
        }
        
        /// Check whether the receiving stop is valid in reference to the given base level and direction.
        public func isValid(forBase base: Decimal, direction: API.Deal.Direction) -> Bool {
            switch self.type {
            case .position(let level):
                switch direction {
                case .buy:  return level < base
                case .sell: return level > base
                }
            case .distance(let distance):
                return distance.isNormal && (distance.sign == .plus)
            }
        }
    }
}

extension API.Deal.Stop {
    public enum Kind {
        /// Absolute value of the stop (e.g. 1.653 USD/EUR).
        /// - parameter level: The stop absolute level.
        case position(level: Decimal)
        /// Relative stop over an undisclosed reference level.
        case distance(Decimal)
    }
    
    /// Defines the amount of risk being exposed while closing the stop loss.
    public enum Risk: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral {
        /// A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
        /// - parameter premium: The number of pips that are being charged for your limited risk (i.e. guaranteed stop).
        case limited(premium: Decimal? = nil)
        case exposed
        
        public init(nilLiteral: ()) {
            self = .exposed
        }
        
        public init(booleanLiteral value: Bool) {
            self = (value) ? .exposed : .limited(premium: nil)
        }
    }
    
    /// A distance from the buy/sell level which will be moved towards the current level in case of a favourable trade.
    public enum Trailing: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral {
        case `static`
        case `dynamic`(Self.Behavior? = nil)
        
        public init(nilLiteral: ()) {
            self = .static
        }
        
        public init(booleanLiteral value: Bool) {
            self = (value) ? .dynamic(nil) : .static
        }
        
        public struct Behavior: Equatable {
            /// The distance from the  market price.
            public let distance: Decimal
            /// The stop level increment step in pips.
            public let increment: Decimal
            
            internal init(distance: Decimal, increment: Decimal) {
                self.distance = distance
                self.increment = increment
            }
        }
    }
}

extension API.Deal {
    /// Profit value and currency.
    public struct ProfitLoss: CustomStringConvertible {
        /// The actual profit value (it can be negative).
        public let value: Decimal
        /// The profit currency.
        public let currency: Currency.Code
        
        internal init(value: Decimal, currency: Currency.Code) {
            self.value = value
            self.currency = currency
        }
        
        public var description: String {
            return "\(self.currency)\(self.value)"
        }
    }
}
