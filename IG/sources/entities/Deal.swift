import Decimals

/// Namespace for commonly used value/class types related to deals.
public enum Deal {
    /// Deal direction.
    public enum Direction: String, Equatable, Codable {
        /// Going "long"
        case buy = "BUY"
        /// Going "short"
        case sell = "SELL"
        
        /// Returns the opposite direction from the receiving direction.
        /// - returns: `.buy` if receiving is `.sell`, and `.sell` if receiving is `.buy`.
        @_transparent public var oppossite: Direction {
            switch self {
            case .buy:  return .sell
            case .sell: return .buy
            }
        }
    }
}

extension Deal {
    /// Position status.
    public enum Status: Decodable {
        case open
        case amended
        case partiallyClosed
        case closed
        case deleted
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            switch value {
            case _Keys.openA.rawValue, _Keys.openB.rawValue: self = .open
            case _Keys.amended.rawValue: self = .amended
            case _Keys.partiallyClosed.rawValue: self = .partiallyClosed
            case _Keys.closedA.rawValue, _Keys.closedB.rawValue: self = .closed
            case _Keys.deleted.rawValue: self = .deleted
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "The status value '\(value)' couldn't be parsed")
            }
        }
        
        private enum _Keys: String, CodingKey {
            case openA = "OPEN", openB = "OPENED"
            case amended = "AMENDED"
            case partiallyClosed = "PARTIALLY_CLOSED"
            case closedA = "FULLY_CLOSED", closedB = "CLOSED"
            case deleted = "DELETED"
        }
    }
}

extension Deal {
    /// Profit value and currency.
    public struct ProfitLoss: CustomStringConvertible {
        /// The actual profit value (it can be negative).
        public let value: Decimal64
        /// The profit currency.
        public let currencyCode: Currency.Code
        
        /// Designated initializer
        internal init(value: Decimal64, currency: Currency.Code) {
            self.value = value
            self.currencyCode = currency
        }
        
        @_transparent public var description: String {
            "\(self.currencyCode)\(self.value)"
        }
    }
}
