/// Namespace for market information.
public enum Market {
    /// An epic represents a unique tradeable market.
    @frozen public struct Epic {
        /// The underlying storage.
        @usableFromInline internal typealias _Buffer = (UInt64, UInt64, UInt64, UInt64)
        /// Maximum UTF8 character count.
        private static var count: Int { 32 }
        
        /// Internal storage safekeeping the UTF8 units and a null character.
        @usableFromInline internal let _storage: _Buffer
        
        /// Unsafe designated initializer.
        ///
        /// This initializer doesn't perform the required type validation. If the provided `value` doesn't satisfy the validation requirement, the behavior is undefined.
        /// - parameter value: String value to be stored as a market epic.
        private init(unchecked value: String) {
            var storage: _Buffer = (0, 0, 0, 0)
            withUnsafeMutableBytes(of: &storage) { $0.copyBytes(from: value.utf8) }
            self._storage = storage
        }
        
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
}

extension Market.Epic: ExpressibleByStringLiteral, LosslessStringConvertible {
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

extension Market.Epic: Hashable, Comparable {
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

extension Market.Epic: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard Self._validate(value) else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid market epic '\(value)'.") }
        self.init(unchecked: value)
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}
