/// IG's account.
public enum Account {
    /// Account identifier "number".
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "The account identifier '\(value)' is not in a valid format")
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
                let reason = "The account identifier being decoded '\(rawValue)' doesn't conform to the validation function"
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
    }
}

extension IG.Account.Identifier {
    /// Returns a Boolean indicating whether the raw value can represent an account identifier.
    ///
    /// For an identifier to be considered valid, it must only contain between 3 and 7 uppercase ASCII characters.
    private static func _validate(_ value: String) -> Bool {
        let count = value.count
        guard count > 2, count < 7 else { return false }
        
        let allowedSet = Set.uppercaseANSI.union(Set.decimalDigits)
        return value.allSatisfy { allowedSet.contains($0) }
    }
}
