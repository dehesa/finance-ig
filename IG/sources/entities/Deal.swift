/// Namespace for commonly used value/class types related to deals.
public enum Deal {
    /// Position's permanent identifier.
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "The deal identifier '\(value)' is not in a valid format")
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self._validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        @_transparent public init?(_ description: String) {
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
        
        @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        @_transparent public var description: String {
            self.rawValue
        }
        
        /// Tests the given argument/rawValue for a matching instance.
        ///
        /// For an identifier to be considered valid, it must only contain between 1 and 30 characters.
        /// - parameter value: The future raw value of this instance.
        private static func _validate(_ value: String) -> Bool {
            let count = value.count
            return (count > 0) && (count < 31)
        }
    }
}

// MARK: -

extension IG.Deal {
    /// Transient deal identifier (for an unconfirmed trade).
    public struct Reference: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "The deal reference '\(value)' is not in a valid format")
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self._validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        @_transparent public init?(_ description: String) {
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
        
        @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        @_transparent public var description: String {
            self.rawValue
        }
        
        /// Tests the given argument/rawValue for a matching instance.
        ///
        /// For an identifier to be considered valid, it must only contain between 1 and 30 characters.
        /// - parameter value: The future raw value of this instance.
        private static func _validate(_ value: String) -> Bool {
            let count = value.count
            guard count > 0, count < 31 else { return false }
            
            let allowedSet = Set<Character>(arrayLiteral: "-", "_", #"\"#).set {
                $0.formUnion(Set.lowercaseANSI)
                $0.formUnion(Set.uppercaseANSI)
                $0.formUnion(Set.decimalDigits)
            }
            return value.allSatisfy { allowedSet.contains($0) }
        }
    }
}

// MARK: -

extension IG.Deal {
    /// Deal direction.
    public enum Direction: String, Equatable, Codable {
        /// Going "long"
        case buy = "BUY"
        /// Going "short"
        case sell = "SELL"
        
        /// Returns the opposite direction from the receiving direction.
        /// - returns: `.buy` if receiving is `.sell`, and `.sell` if receiving is `.buy`.
        @_transparent public var oppossite: Direction {
            switch self {
            case .buy:  return .sell
            case .sell: return .buy
            }
        }
    }
}

extension IG.Deal {
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
}

extension IG.Deal {
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
        
        @_transparent public var description: String {
            "\(self.currencyCode)\(self.value)"
        }
    }
}
