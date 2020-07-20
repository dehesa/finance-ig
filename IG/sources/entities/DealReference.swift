extension Deal {
    /// Transient deal identifier (for an unconfirmed trade).
    public struct Reference: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable {
        public let rawValue: String
        
        public init?(rawValue: String) {
            guard Self._validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "Invalid deal reference '\(value)'.")
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

extension Deal.Reference: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
        
        guard Self._validate(self.rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid deal reference '\(self.rawValue)'.")
        }
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
