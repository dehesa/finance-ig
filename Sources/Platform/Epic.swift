import Foundation

/// An epic represents a unique tradeable market.
public struct Epic: RawRepresentable, Codable, ExpressibleByStringLiteral, Hashable, CustomStringConvertible {
    public let rawValue: String
    /// The allowed character set for epics.
    ///
    /// It is used on validation.
    private static let allowedSet: CharacterSet = {
        var result = CharacterSet(arrayLiteral: ".", "_")
        result.formUnion(CharacterSet.IG.lowercaseANSI)
        result.formUnion(CharacterSet.IG.uppercaseANSI)
        result.formUnion(CharacterSet.decimalDigits)
        return result
    }()
    
    public init(stringLiteral value: String) {
        guard Self.validate(value) else { fatalError("The epic couldn't be identified or is not in the correct format.") }
        self.rawValue = value
    }
    
    public init?(rawValue: String) {
        guard Epic.validate(rawValue) else { return nil }
        self.rawValue = rawValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard Self.validate(rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "The given string doesn't conform to the regex pattern.")
        }
        self.rawValue = rawValue
    }
    
    public var description: String {
        return self.rawValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
    
    private static func validate(_ value: String) -> Bool {
        let allowedRange = 6...30
        return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
    }
}
