/// Namespace for market information.
public enum Market {
    /// An epic represents a unique tradeable market.
    public struct Epic: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "The market epic '\(value)' is not in a valid format")
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self._validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        @_transparent public init?(_ description: String) {
            self.init(rawValue: description)
        }
        
        @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        @_transparent public var description: String {
            self.rawValue
        }
    }
}

extension Market.Epic: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        guard Self._validate(rawValue) else {
            let reason = "The market epic being decoded '\(rawValue)' doesn't conform to the validation function"
            throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
        }
        self.rawValue = rawValue
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension Market.Epic {
    /// Returns a Boolean indicating whether the raw value can represent a market epic.
    ///
    /// For an identifier to be considered valid, it must only contain between 6 and 30 ASCII characters.
    private static func _validate(_ value: String) -> Bool {
        let count = value.count
        guard count > 5, count < 31 else { return false }
        
        let allowedSet = Set<Character>(arrayLiteral: ".", "_").set {
            $0.formUnion(Set.lowercaseANSI)
            $0.formUnion(Set.uppercaseANSI)
            $0.formUnion(Set.decimalDigits)
        }
        return value.allSatisfy { allowedSet.contains($0) }
    }
}
