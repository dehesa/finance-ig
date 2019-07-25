import Foundation

/// One of the currencies as described in ISO 4217.
public struct Currency: RawRepresentable, Codable, ExpressibleByStringLiteral, Hashable, CustomStringConvertible {
    public let rawValue: String
    
    public init(stringLiteral value: String) {
        guard Self.validate(value) else { fatalError("The currency code couldn't be identified or is not in the correct format.") }
        self.rawValue = value
    }
    
    public init?(rawValue: String) {
        guard Self.validate(rawValue) else { return nil }
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
        let characterSet = CharacterSet.Framework.uppercaseANSI
        return value.count == 3 && value.unicodeScalars.allSatisfy { characterSet.contains($0) }
    }
}
