extension Deal {
    /// Position's permanent identifier.
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable {
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
        
        @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        @_transparent public var description: String {
            self.rawValue
        }
    }
}

extension Deal.Identifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        guard Self._validate(rawValue) else {
            let reason = "The deal identifier being decoded '\(rawValue)' doesn't conform to the validation function"
            throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
        }
        self.rawValue = rawValue
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension Deal.Identifier {
    /// Tests the given argument/rawValue for a matching instance.
    ///
    /// For an identifier to be considered valid, it must only contain between 1 and 30 characters.
    /// - parameter value: The future raw value of this instance.
    private static func _validate(_ value: String) -> Bool {
        let count = value.count
        return (count > 0) && (count < 31)
    }
}
