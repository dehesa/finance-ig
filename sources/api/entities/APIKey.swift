extension API {
    /// API development key.
    public struct Key {
        /// The underlying storage.
        @usableFromInline internal typealias _Buffer = (UInt64, UInt64, UInt64, UInt64, UInt64)
        /// Maximum UTF8 character count.
        private static var count: Int { 40 }
        
        /// Internal storage safekeeping the UTF8 units and a null character.
        @usableFromInline internal let _storage: _Buffer
        
        /// Unsafe designated initializer.
        ///
        /// This initializer doesn't perform the required type validation. If the provided `value` doesn't satisfy the validation requirement, the behavior is undefined.
        /// - parameter value: String value to be stored as a market epic.
        private init(unchecked value: String) {
            var storage: _Buffer = (0, 0, 0, 0, 0)
            withUnsafeMutableBytes(of: &storage) { $0.copyBytes(from: value.utf8) }
            self._storage = storage
        }
        
        /// Returns a Boolean indicating whether the raw value can represent an API key.
        private static func _validate(_ value: String) -> Bool {
            let allowedSet = Set.lowercaseANSI ∪ Set.decimalDigits
            return (value.count == 40) && value.allSatisfy { allowedSet.contains($0) }
        }
    }
}

extension API.Key: ExpressibleByStringLiteral, LosslessStringConvertible {
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
            $0.withMemoryRebound(to: Unicode.ASCII.CodeUnit.self, capacity: Self.count) {
                String(decoding: UnsafeBufferPointer(start: $0, count: Self.count), as: Unicode.ASCII.self)
            }
        }
    }
}

extension API.Key: Hashable, Comparable {
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

extension API.Key: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard Self._validate(value) else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid API key '\(value)'.") }
        self.init(unchecked: value)
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}
