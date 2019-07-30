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
    
    /// Position status.
    public enum Status: Decodable {
        case open
        case amended
        case partiallyClosed
        case closed
        case deleted
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            switch value {
            case Self.CodingKeys.openA.rawValue, Self.CodingKeys.openB.rawValue: self = .open
            case Self.CodingKeys.amended.rawValue: self = .amended
            case Self.CodingKeys.partiallyClosed.rawValue: self = .partiallyClosed
            case Self.CodingKeys.closedA.rawValue, Self.CodingKeys.closedB.rawValue: self = .closed
            case Self.CodingKeys.deleted.rawValue: self = .deleted
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "The status value \"\(value)\" couldn't be parsed.")
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case openA = "OPEN", openB = "OPENED"
            case amended = "AMENDED"
            case partiallyClosed = "PARTIALLY_CLOSED"
            case closedA = "FULLY_CLOSED", closedB = "CLOSED"
            case deleted = "DELETED"
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
        /// - parameter reference: The reference level and deal direction. `.buy` deals will have the limits higher than the reference levels, while `.sell` deals will have then lower.
        /// - returns: The level value. It may only be `nil` when the receiving limit is a `.distance` and no reference level and direction has been given.
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
        /// - parameter reference: The reference level and deal direction. `.buy` deals will have the limits higher than the reference levels, while `.sell` deals will have then lower.
        /// - returns: The distance between the reference level and the receiving level. It may only be `nil` when the receiving limit is a `.position` and no reference level and direction has been given.
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
        /// - parameter reference. The reference level and deal direction.
        /// - returns: Boolean indicating whether the limit is in the right side of the deal and the number is valid.
        public func isValid(with reference: (base: Decimal, direction: API.Deal.Direction)? = nil) -> Bool {
            switch self {
            case .distance(let distance):
                guard distance.isNormal, case .plus = distance.sign else { return false }
                return true
            case .position(let level):
                guard let reference = reference else { return true }
                
                switch reference.direction {
                case .buy:  return level > reference.base
                case .sell: return level < reference.base
                }
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
        /// - parameter type: The type of stop (whether an absolute stop level or relative stop distance).
        /// - parameter risk: The risk exposed when exercising the stop loss.
        /// - parameter trailing: Indicates whether the stop should be dynamic (i.e. trailing) or static (i.e. not trailing).
        internal init(_ type: Self.Kind, risk: Self.Risk, trailing: Self.Trailing) {
            self.type = type
            self.risk = risk
            self.trailing = trailing
        }
        
        /// Boolean indicating whether the stop will trail (be dynamic) or not (be static).
        public var isTrailing: Bool {
            switch self.trailing {
            case .static:  return false
            case .dynamic: return true
            }
        }
        
        /// Check whether the receiving stop is valid in reference to the given base level and direction.
        /// - parameter reference. The reference level and deal direction.
        /// - returns: Boolean indicating whether the stop is in the right side of the deal and the number is valid.
        public func isValid(with reference: (base: Decimal, direction: API.Deal.Direction)? = nil) -> Bool {
            switch self.type {
            case .distance(let distance):
                guard distance.isNormal, case .plus = distance.sign else { return false }
                return true
            case .position(let level):
                guard let reference = reference else { return true }
                
                switch reference.direction {
                case .buy:  return level < reference.base
                case .sell: return level > reference.base
                }
            }
        }
        
        ///
        public static func position(level: Decimal, isStopGuaranteed: Bool = false) -> Self {
            return self.init(.position(level: level), risk: (isStopGuaranteed) ? .limited(premium: nil) : .exposed, trailing: .static)
        }
        
        ///
        public static func distance(_ distance: Decimal, isStopGuaranteed: Bool = false) -> Self {
            return self.init(.distance(distance), risk: (isStopGuaranteed) ? .limited(premium: nil) : .exposed, trailing: .static)
        }
        
        ///
        public static func trailing(_ distance: Decimal, increment: Decimal) -> Self {
            return self.init(.distance(distance), risk: .exposed, trailing: .dynamic(.init(distance: distance, increment: increment)))
        }
    }
}

extension API.Deal.Stop {
    /// Available types of stops.
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
        /// An exposed (or non-guaranteed) stop may expose the trade to slippage when exiting it.
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
        /// A static (non-movable) stop.
        case `static`
        /// A dynamic (trailing) stop.
        case `dynamic`(Self.Settings? = nil)
        
        public init(nilLiteral: ()) {
            self = .static
        }
        
        public init(booleanLiteral value: Bool) {
            self = (value) ? .dynamic(nil) : .static
        }
        
        /// The trailing settings (i.e. trailing distance and trailing increment/step).
        public struct Settings: Equatable {
            /// The distance from the  market price.
            public let distance: Decimal
            /// The stop level increment step in pips.
            public let increment: Decimal
            /// Designated initializer.
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
        /// Designated initializer
        internal init(value: Decimal, currency: Currency.Code) {
            self.value = value
            self.currency = currency
        }
        
        public var description: String {
            return "\(self.currency)\(self.value)"
        }
    }
}
