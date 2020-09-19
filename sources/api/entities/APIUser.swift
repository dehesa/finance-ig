extension API {
    /// A user within the platform.
    public struct User: ExpressibleByArrayLiteral {
        /// Platform's username.
        public let name: Self.Name
        /// The user's given password.
        public let password: Self.Password
        
        /// Initializer providing already with fully formed sub-instances.
        /// - parameter name: The user's platform name.
        /// - parameter password: The user's password.
        @_transparent public init(_ name: Self.Name, _ password: Self.Password) {
            self.name = name
            self.password = password
        }
        
        /// Failable initializer providing the user's intro credentials.
        /// - parameter name: The user's platform name.
        /// - parameter password: The user's password.
        /// - returns: `nil` if the objects were malformed.
        @_transparent public init?(name: String, passsword: String) {
            guard let username = Self.Name(name),
                  let password = Self.Password(rawValue: passsword) else { return nil }
            self.init(username, password)
        }
        
        @_transparent public init(arrayLiteral elements: String...) {
            precondition(elements.count == 2, "A '\(API.self).\(Self.self)' type can only be initialized with an array with two non-empty strings")
            self.init(.init(stringLiteral: elements[0]), .init(stringLiteral: elements[1]))
        }
    }
}

extension API.User {
    /// The user identifier within the platform.
    public struct Name: ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable {
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
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "Invalid username '\(value)'.")
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
}

extension API.User {
    /// The user's password within the platform.
    public struct Password: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable {
        public let rawValue: String
        
        public init?(rawValue: String) {
            guard Self._validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "Invalid user password format.")
            self.rawValue = value
        }
        
        @inlinable public init?(_ description: String) {
            self.init(rawValue: description)
        }
        
        @_transparent public var description: String {
            self.rawValue
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        private static func _validate(_ value: String) -> Bool {
            let count = value.count
            return (count > 0) && (count < 351)
        }
    }
}

// MARK: -

extension API.User.Name: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard Self._validate(value) else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid username '\(value)'.") }
        self.init(unchecked: value)
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}

extension API.User.Password: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
        
        guard Self._validate(self.rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid user password.")
        }
    }
    
    @_transparent public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
