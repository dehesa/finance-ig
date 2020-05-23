extension IG.API {
    /// API development key.
    public struct Key: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "The API key provided is not in a valid format")
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
                let reason = "The API key being decoded doesn't conform to the validation function"
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

extension IG.API.Key {
    /// Returns a Boolean indicating whether the raw value can represent an API key.
    private static func _validate(_ value: String) -> Bool {
        let allowedSet = Set.lowercaseANSI.union(Set.decimalDigits)
        return (value.count == 40) && value.allSatisfy { allowedSet.contains($0) }
    }
}
