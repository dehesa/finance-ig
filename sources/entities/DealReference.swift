extension Deal {
    /// Transient deal identifier (for an unconfirmed trade).
    @frozen public struct Reference {
        /// The underlying storage.
        @usableFromInline internal typealias _Buffer = (UInt64, UInt64, UInt64, UInt64)
        /// Maximum UTF8 character count.
        private static var count: Int { 32 }
        
        /// Internal storage safekeeping the UTF8 units and a null character.
        @usableFromInline internal let _storage: _Buffer
        
        /// Unsafe designated initializer.
        ///
        /// This initializer doesn't perform the required type validation. If the provided `value` doesn't satisfy the validation requirement, the behavior is undefined.
        /// - parameter value: String value to be stored as a deal reference.
        private init(unchecked value: String) {
            var storage: _Buffer = (0, 0, 0, 0)
            withUnsafeMutableBytes(of: &storage) { $0.copyBytes(from: value.utf8) }
            self._storage = storage
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

extension Deal.Reference: ExpressibleByStringLiteral, LosslessStringConvertible {
    public init(stringLiteral value: String) {
        precondition(Self._validate(value), "Invalid market epic '\(value)'.")
        self.init(unchecked: value)
    }
    
    public init?(_ description: String) {
        guard Self._validate(description) else { return nil }
        self.init(unchecked: description)
    }
    
    public var description: String {
        withUnsafePointer(to: self._storage) {
            $0.withMemoryRebound(to: UInt8.self, capacity: Self.count) {
                String(cString: $0)
            }
        }
    }
}

extension Deal.Reference: Hashable, Comparable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._storage == rhs._storage
    }
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs._storage < rhs._storage
    }
    
    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: self._storage) { hasher.combine(bytes: $0) }
    }
}

// MARK: -

extension Deal.Reference: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard Self._validate(value) else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid deal reference '\(value)'.") }
        self.init(unchecked: value)
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}
