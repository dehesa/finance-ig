import Foundation

extension IG.API {
    /// A user within the platform.
    public struct User: ExpressibleByArrayLiteral, CustomDebugStringConvertible {
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
        public init?(name: String, passsword: String) {
            guard let username = Self.Name(rawValue: name),
                  let pass = Self.Password(rawValue: passsword) else { return nil }
            self.name = username
            self.password = pass
        }
        
        public init(arrayLiteral elements: String...) {
            guard elements.count == 2 else { fatalError(#"A "\#(Self.self)" type can only be initialized with an array with two non-empty strings."#)}
            self.name = .init(stringLiteral: elements[0])
            self.password = .init(stringLiteral: elements[1])
        }
        
        public var debugDescription: String {
            var result = IG.DebugDescription("API User")
            result.append("name", self.name)
            result.append("password", String(repeating: "*", count: self.password.rawValue.count))
            return result.generate()
        }
    }
}

extension IG.API.User {
    /// The user identifier within the platform.
    public struct Name: RawRepresentable, ExpressibleByStringLiteral, Codable, Hashable, CustomStringConvertible {
        public let rawValue: String
        
        public init?(rawValue: String) {
            guard Self.validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError(#"The username "\#(value)" is not in a valid format."#) }
            self.rawValue = value
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let name = try container.decode(String.self)
            guard Self.validate(name) else {
                let reason = #"The username "\#(name)" doesn't conform to the validation function."#
                throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
            }
            self.rawValue = name
        }
        
        public var description: String {
            return self.rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
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
}

extension IG.API.User {
    /// The user's password within the platform.
    public struct Password: ExpressibleByStringLiteral, Codable {
        fileprivate let rawValue: String
        
        public init?(rawValue: String) {
            guard Self.validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError("The password is not in a valid format.") }
            self.rawValue = value
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let password = try container.decode(String.self)
            guard Self.validate(password) else {
                let reason = "The password being decoded doesn't conform to the validation function."
                throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
            }
            self.rawValue = password
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        private static func validate(_ value: String) -> Bool {
            let allowedRange = 1...350
            return allowedRange.contains(value.count)
        }
    }
}
