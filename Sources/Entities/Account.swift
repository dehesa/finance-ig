import Foundation

/// IG's account.
public enum Account {
    /// Account identifier "number".
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, Codable, Hashable, CustomStringConvertible {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError("The account identifier provided is not in the valid format") }
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
                let reason = "The account identifier being decoded doesn't conform to the validation function"
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

extension IG.Account.Identifier {
    /// Returns a Boolean indicating whether the raw value can represent an account identifier.
    private static func validate(_ value: String) -> Bool {
        let allowedRange = 3...6
        return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
    }
    
    /// The allowed character set for the account identifier. It is used on validation.
    private static let allowedSet: CharacterSet = {
        var result = CharacterSet.decimalDigits
        result.formUnion(CharacterSet.uppercaseANSI)
        return result
    }()
}
