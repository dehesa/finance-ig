import Foundation

/// Namespace for market information.
public enum Market {
    /// An epic represents a unique tradeable market.
    public struct Epic: RawRepresentable, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError(#"The market epic "\#(value)" is not in a valid format"#) }
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
            let rawValue = try container.decode(String.self)
            guard Self.validate(rawValue) else {
                let reason = #"The market epic being decoded "\#(rawValue)" doesn't conform to the validation function"#
                throw DecodingError.dataCorruptedError(in: container, debugDescription: reason)
            }
            self.rawValue = rawValue
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            return lhs.rawValue < rhs.rawValue
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

extension IG.Market.Epic {
    /// Returns a Boolean indicating whether the raw value can represent a market epic.
    private static func validate(_ value: String) -> Bool {
        let allowedRange = 6...30
        return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
    }
    
    /// The allowed character set for epics.
    ///
    /// It is used on validation.
    private static let allowedSet: CharacterSet = {
        var result = CharacterSet(arrayLiteral: ".", "_")
        result.formUnion(CharacterSet.lowercaseANSI)
        result.formUnion(CharacterSet.uppercaseANSI)
        result.formUnion(CharacterSet.decimalDigits)
        return result
    }()
}
