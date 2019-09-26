import Foundation

extension IG.API {
    /// A user within the platform.
    public struct User: ExpressibleByArrayLiteral {
        /// Platform's username.
        public let name: Self.Name
        /// The user's given password.
        internal let password: Self.Password
        
        /// Initializer providing already with fully formed sub-instances.
        /// - parameter name: The user's platform name.
        /// - parameter password: The user's password.
        public init(_ name: Self.Name, _ password: Self.Password) {
            self.name = name
            self.password = password
        }
        
        /// Failable initializer providing the user's intro credentials.
        /// - parameter name: The user's platform name.
        /// - parameter password: The user's password.
        /// - returns: `nil` if the objects were malformed.
        public init?(name: Self.Name.RawValue, passsword: String) {
            guard let username = Self.Name(rawValue: name),
                  let pass = Self.Password(rawValue: passsword) else { return nil }
            self.name = username
            self.password = pass
        }
        
        public init(arrayLiteral elements: String...) {
            guard elements.count == 2 else { fatalError(#"A "\#(Self.self)" type can only be initialized with an array with two non-empty strings"#)}
            self.name = .init(stringLiteral: elements[0])
            self.password = .init(stringLiteral: elements[1])
        }
    }
}

extension IG.API.User {
    /// The user identifier within the platform.
    public struct Name: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError(#"The username "\#(value)" is not in a valid format"#) }
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self.validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init?(_ description: String) {
            self.init(rawValue: description)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let name = try container.decode(String.self)
            guard Self.validate(name) else {
                let reason = #"The username "\#(name)" doesn't conform to the validation function"#
                throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
            }
            self.rawValue = name
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        public var description: String {
            return self.rawValue
        }
    }
}

extension IG.API.User {
    /// The user's password within the platform.
    public struct Password: ExpressibleByStringLiteral, Encodable {
        fileprivate let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError("The password is not in a valid format") }
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self.validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
    }
}

extension IG.API.User: IG.DebugDescriptable {
    static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("name", self.name)
        result.append("password", String(repeating: "*", count: self.password.rawValue.count))
        return result.generate()
    }
}

extension IG.API.User.Name {
    private static func validate(_ value: String) -> Bool {
        let allowedRange = 1...30
        return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
    }
    
    /// The allowed character set for username. It is used on validation.
    private static let allowedSet: CharacterSet = {
        var result = CharacterSet(arrayLiteral: #"\"#, "-", "_")
        result.formUnion(CharacterSet.lowercaseANSI)
        result.formUnion(CharacterSet.uppercaseANSI)
        result.formUnion(CharacterSet.decimalDigits)
        return result
    }()
}

extension IG.API.User.Password {
    private static func validate(_ value: String) -> Bool {
        let allowedRange = 1...350
        return allowedRange.contains(value.count)
    }
}
