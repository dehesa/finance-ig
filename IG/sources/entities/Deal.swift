import Decimals

/// Namespace for commonly used value/class types related to deals.
public enum Deal {
    /// Deal direction.
    public enum Direction: Equatable {
        /// Going "long"
        case buy
        /// Going "short"
        case sell
        
        /// Returns the opposite direction from the receiving direction.
        /// - returns: `.buy` if receiving is `.sell`, and `.sell` if receiving is `.buy`.
        public var oppossite: Direction {
            switch self {
            case .buy:  return .sell
            case .sell: return .buy
            }
        }
    }

    /// Position status.
    public enum Status {
        case opened
        case amended
        case closed(Self.Completion)
        case deleted
        
        public enum Completion {
            case partially
            case fully
        }
    }

    /// Profit value and currency.
    public struct ProfitLoss {
        /// The actual profit value (it can be negative).
        public let value: Decimal64
        /// The profit currency.
        public let currency: Currency.Code
        
        /// Designated initializer
        internal init(value: Decimal64, currency: Currency.Code) {
            self.value = value
            self.currency = currency
        }
    }
}

// MARK: -

extension Deal.Direction: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case _Values.buy: self = .buy
        case _Values.sell: self = .sell
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid deal direction '\(value)'.")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .buy: try container.encode(_Values.buy)
        case .sell: try container.encode(_Values.sell)
        }
    }
    
    private enum _Values {
        static var buy: String { "BUY" }
        static var sell: String { "SELL"}
    }
}

extension Deal.Status: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "OPEN", "OPENED": self = .opened
        case "AMENDED": self = .amended
        case "PARTIALLY_CLOSED": self = .closed(.partially)
        case "FULLY_CLOSED", "CLOSED": self = .closed(.fully)
        case "DELETED": self = .deleted
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid deal status '\(value)'.")
        }
    }
}
