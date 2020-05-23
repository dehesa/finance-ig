/// IG's client.
public enum Client {
    /// Client identifier "number".
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "The client identifier '\(value)' is not in a valid format")
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
                let reason = "The client identifier being decoded '\(rawValue)' doesn't conform to the validation function"
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

extension IG.Client.Identifier {
    /// Returns a Boolean indicating whether the raw value can represent a client identifier.
    ///
    /// For an identifier to be considered valid, it must only contain between 8 and 10 decimal digits characters.
    private static func _validate(_ value: String) -> Bool {
        let count = value.count
        guard count > 7, count < 11 else { return false }
        
        let allowedSet = Set.decimalDigits
        return value.allSatisfy { allowedSet.contains($0) }
    }
}
