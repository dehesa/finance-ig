import Foundation

/// Namespace for commonly used value/class types related to deals.
public enum Deal {
    /// Position's permanent identifier.
    public struct Identifier: RawRepresentable, ExpressibleByStringLiteral, Codable, CustomStringConvertible, Hashable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError(#"The deal identifier "\#(value)" is not in a valid format."#) }
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
                throw DecodingError.dataCorruptedError(in: container, debugDescription: #"The deal identifier being decoded "\#(rawValue)" doesn't conform to the validation function."#)
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
        
        /// Tests the given argument/rawValue for a matching instance.
        /// - parameter value: The future raw value of this instance.
        private static func validate(_ value: String) -> Bool {
            return (1...30).contains(value.count)
        }
    }
}

extension IG.Deal {
    /// Transient deal identifier (for an unconfirmed trade).
    public struct Reference: RawRepresentable, ExpressibleByStringLiteral, Codable, CustomStringConvertible, Hashable {
        public let rawValue: String
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError(#"The deal reference "\#(value)" is not in a valid format."#) }
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
                throw DecodingError.dataCorruptedError(in: container, debugDescription: #"The deal reference being decoded "\#(rawValue)" doesn't conform to the validation function."#)
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
        
        /// The allowed character set used on validation.
        private static let allowedSet: CharacterSet = {
            var result = CharacterSet(arrayLiteral: "_", "-", #"\"#)
            result.formUnion(CharacterSet.lowercaseANSI)
            result.formUnion(CharacterSet.uppercaseANSI)
            result.formUnion(CharacterSet.decimalDigits)
            return result
        }()
        
        /// Tests the given argument/rawValue for a matching instance.
        /// - parameter value: The future raw value of this instance.
        private static func validate(_ value: String) -> Bool {
            let allowedRange = 1...30
            return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
        }
    }
}

extension IG.Deal {
    /// Deal direction.
    public enum Direction: String, Equatable, Codable {
        /// Going "long"
        case buy = "BUY"
        /// Going "short"
        case sell = "SELL"
        
        /// Returns the opposite direction from the receiving direction.
        /// - returns: `.buy` if receiving is `.sell`, and `.sell` if receiving is `.buy`.
        public var oppossite: Direction {
            switch self {
            case .buy:  return .sell
            case .sell: return .buy
            }
        }
    }
}
