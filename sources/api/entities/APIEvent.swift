import Foundation
import Decimals

extension API {
    /// Economic calendar with economic *happenings*.
    public enum Calendar {
        /// An economic event that has heppened or is targeted to happen.
        public struct Event {
            /// The specific date and time when the economic event is happening.
            public let date: Date
            /// The title of the economic event.
            public let headline: String
            /// The previous recurring event value.
            public let previous: Self.Value?
            /// The expected recurring event value.
            public let expected: Self.Value?
            /// The actual recurring event value.
            public let actual: Self.Value?
            /// The country code.
            public let country: Country
        }
    }
}

extension API.Calendar.Event {
    /// A calendar event value (usually representing a previous, expected, and actual value).
    public enum Value {
        /// A simple number value.
        case number(Decimal64)
        /// A closed range of values.
        case range(ClosedRange<Decimal64>)
        /// A non-supported values.
        case unknown(String)
    }
}

// MARK: -

extension API.Calendar.Event: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        
        let timestamp = try container.decode(Int.self, forKey: .date)
        self.date = Date(timeIntervalSince1970: Double(timestamp / 1000))
        self.country = try container.decode(Country.self, forKey: .country)
        self.headline = try container.decode(String.self, forKey: .headline)
        
        let nestedContainer = try container.nestedContainer(keyedBy: _Keys._NestedKeys.self, forKey: .data)
        self.previous = try nestedContainer.decodeIfPresent(Self.Value.self, forKey: .previous)
        self.expected = try nestedContainer.decodeIfPresent(Self.Value.self, forKey: .expected)
        self.actual = try nestedContainer.decodeIfPresent(Self.Value.self, forKey: .actual)
    }
    
    private enum _Keys: String, CodingKey {
        case type
        case date = "timestamp"
        case headline
        case country = "countryCode"
        case data = "eventTypeData"
        
        enum _NestedKeys: String, CodingKey {
            case previous = "previousValue"
            case expected = "expectedValue"
            case actual = "actualValue"
        }
    }
}

extension API.Calendar.Event.Value: Decodable, CustomDebugStringConvertible {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        let substrings = string.components(separatedBy: " - ")
        guard substrings.count != 2 else {
            if let lowerBound = Decimal64(substrings[0]),
                let upperBound = Decimal64(substrings[1]) {
                self = .range(.init(uncheckedBounds: (lowerBound, upperBound)))
            } else { self = .unknown(string) }; return
        }
        
        guard let number = Decimal64(string) else {
            self = .unknown(string); return
        }
        
        guard string._droppingTrailingZeros == String(describing: number) else {
            self = .unknown(string); return
        }
        
        self = .number(number)
    }
    
    public var debugDescription: String {
        switch self {
        case .number(let number): return .init(describing: number)
        case .range(let range): return "\(range.lowerBound)...\(range.upperBound)"
        case .unknown(let string): return string
        }
    }
}

private extension String {
    /// Drops the trailing ".0" or ".00" (.etc) from a `String` representing a number.
    var _droppingTrailingZeros: String {
        guard self.contains(".") else { return self }
        
        var result: String.SubSequence = .init(self)
        while result.hasSuffix("0") {
            result = result.dropLast(1)
        }
        
        if result.hasSuffix(".") {
            result = result.dropLast(1)
        }
        
        return String(result)
    }
}
