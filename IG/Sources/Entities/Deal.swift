import Foundation

/// Namespace for commonly used value/class types related to deals.
public enum Deal {
    /// Position's permanent identifier.
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self._validate(value) else { fatalError("The deal identifier '\(value)' is not in a valid format") }
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self._validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init?(_ description: String) {
            self.init(rawValue: description)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard Self._validate(rawValue) else {
                let reason = "The deal identifier being decoded '\(rawValue)' doesn't conform to the validation function"
                throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
            }
            self.rawValue = rawValue
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        public var description: String {
            self.rawValue
        }
    }
}

extension IG.Deal.Identifier {
    /// Tests the given argument/rawValue for a matching instance.
    /// - parameter value: The future raw value of this instance.
    private static func _validate(_ value: String) -> Bool {
        (1...30).contains(value.count)
    }
}

extension IG.Deal {
    /// Transient deal identifier (for an unconfirmed trade).
    public struct Reference: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self._validate(value) else { fatalError("The deal reference '\(value)' is not in a valid format") }
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self._validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init?(_ description: String) {
            self.init(rawValue: description)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard Self._validate(rawValue) else {
                let reason = "The deal reference being decoded '\(rawValue)' doesn't conform to the validation function"
                throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
            }
            self.rawValue = rawValue
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        public var description: String {
            self.rawValue
        }
    }
}

extension IG.Deal.Reference {
    /// Tests the given argument/rawValue for a matching instance.
    /// - parameter value: The future raw value of this instance.
    private static func _validate(_ value: String) -> Bool {
        let allowedRange = 1...30
        return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { _allowedSet.contains($0) }
    }
    
    /// The allowed character set used on validation.
    private static let _allowedSet: CharacterSet = {
        CharacterSet(arrayLiteral: "_", "-", #"\"#).set {
            $0.formUnion(CharacterSet.lowercaseANSI)
            $0.formUnion(CharacterSet.uppercaseANSI)
            $0.formUnion(CharacterSet.decimalDigits)
        }
    }()
}

extension IG.Deal {
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
    
    /// Position status.
    public enum Status: Decodable, CustomDebugStringConvertible {
        case open
        case amended
        case partiallyClosed
        case closed
        case deleted
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            switch value {
            case _CodingKeys.openA.rawValue, _CodingKeys.openB.rawValue: self = .open
            case _CodingKeys.amended.rawValue: self = .amended
            case _CodingKeys.partiallyClosed.rawValue: self = .partiallyClosed
            case _CodingKeys.closedA.rawValue, _CodingKeys.closedB.rawValue: self = .closed
            case _CodingKeys.deleted.rawValue: self = .deleted
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "The status value '\(value)' couldn't be parsed")
            }
        }
        
        private enum _CodingKeys: String, CodingKey {
            case openA = "OPEN", openB = "OPENED"
            case amended = "AMENDED"
            case partiallyClosed = "PARTIALLY_CLOSED"
            case closedA = "FULLY_CLOSED", closedB = "CLOSED"
            case deleted = "DELETED"
        }
        
        public var debugDescription: String {
            switch self {
            case .open: return "opened"
            case .amended: return "amended"
            case .partiallyClosed: return "closed (partially)"
            case .closed: return "closed (fully)"
            case .deleted: return "deleted"
            }
        }
    }
    
    /// Profit value and currency.
    public struct ProfitLoss: CustomStringConvertible {
        /// The actual profit value (it can be negative).
        public let value: Decimal
        /// The profit currency.
        public let currencyCode: IG.Currency.Code
        /// Designated initializer
        internal init(value: Decimal, currency: IG.Currency.Code) {
            self.value = value
            self.currencyCode = currency
        }
        
        public var description: String {
            "\(self.currencyCode)\(self.value)"
        }
    }
}
