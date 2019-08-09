import Foundation

extension API {
    /// API development key.
    public struct Key: RawRepresentable, ExpressibleByStringLiteral, Codable, Hashable, CustomStringConvertible {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError("The API key provided is not in a valid format.") }
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self.validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let name = try container.decode(String.self)
            guard Self.validate(name) else {
                let reason = "The API key being decoded doesn't conform to the validation function."
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
    }
}

extension API.Key {
    /// Returns a Boolean indicating whether the raw value can represent an API key.
    private static func validate(_ value: String) -> Bool {
        return value.count == 40 && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
    }
    
    /// The allowed character set for the API key. It is used on validation.
    private static let allowedSet: CharacterSet = {
        var result = CharacterSet.decimalDigits
        result.formUnion(CharacterSet.IG.lowercaseANSI)
        return result
    }()
}
