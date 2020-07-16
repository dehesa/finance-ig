extension Deal {
    /// Transient deal identifier (for an unconfirmed trade).
    public struct Reference: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable {
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
        
        @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
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

extension Deal.Reference: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
        
        guard Self._validate(self.rawValue) else {
            let reason = "The deal reference being decoded '\(self.rawValue)' doesn't conform to the validation function"
            throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
        }
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
