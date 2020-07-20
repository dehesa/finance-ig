/// IG's account.
public enum Account {
    /// Account identifier "number".
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable {
        public let rawValue: String
        
        public init?(rawValue: String) {
            guard Self._validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "Invalid account identifier '\(value)'.")
            self.rawValue = value
        }
        
        @_transparent public init?(_ description: String) {
            self.init(rawValue: description)
        }
        
        @_transparent public var description: String {
            self.rawValue
        }
        
        @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        /// Returns a Boolean indicating whether the raw value can represent an account identifier.
        ///
        /// For an identifier to be considered valid, it must only contain between 3 and 7 uppercase ASCII characters.
        private static func _validate(_ value: String) -> Bool {
            let count = value.count
            guard count > 2, count < 7 else { return false }
            
            let allowedSet = Set.uppercaseANSI ∪ Set.decimalDigits
            return value.allSatisfy { allowedSet.contains($0) }
        }
    }
}

// MARK: -

extension Account.Identifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
        
        guard Self._validate(self.rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid account identifier '\(self.rawValue)'.")
        }
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
