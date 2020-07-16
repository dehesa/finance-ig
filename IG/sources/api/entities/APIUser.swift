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
            guard let username = Self.Name(rawValue: name),
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
    public struct Name: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "The username '\(value)' is not in a valid format")
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
            let name = try container.decode(String.self)
            guard Self._validate(name) else {
                let reason = "The username '\(name)' doesn't conform to the validation function"
                throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
            }
            self.rawValue = name
        }
        
        @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        @_transparent public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        public var description: String {
            self.rawValue
        }
    }
}

extension API.User {
    /// The user's password within the platform.
    public struct Password: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            precondition(Self._validate(value), "The password is not in a valid format")
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self._validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        @inlinable public init?(_ description: String) {
            self.init(rawValue: description)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let password = try container.decode(String.self)
            guard Self._validate(password) else {
                let reason = "The password doesn't conform to the validation function"
                throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
            }
            self.rawValue = password
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        @_transparent public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        @_transparent public var description: String {
            self.rawValue
        }
    }
}

extension API.User.Name {
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

extension API.User.Password {
    private static func _validate(_ value: String) -> Bool {
        let count = value.count
        return (count > 0) && (count < 351)
    }
}
