import Combine
import Foundation
import Decimals

extension API.Request {
    /// List of endpoints scrapped from the website.
    ///
    /// This endpoints require specific usage and won't work with the API key settings.
    public struct Scrapped {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        internal unowned let api: API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        @usableFromInline internal init(api: API) { self.api = api }
    }
}

extension API.Request.Scrapped {
    
    // MARK: GET /chartscalendar/events
    
    /// Returns a list of events happening between the given dates in the economic calendar.
    /// - parameter epic: Instrument's epic (e.g. `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - returns: *Future* forwarding all user's applications.
    public func getEvents(epic: IG.Market.Epic, from: Date, to: Date, rootURL: URL = API.scrappedRootURL, scrappedCredentials: (cst: String, security: String)) -> AnyPublisher<[API.Calendar.Event],API.Error> {
        self.api.publisher { _ throws -> (from: Int, to: Int) in
                guard from <= to else { throw API.Error.invalidRequest("The 'from' date must occur before the 'to' date", suggestion: .readDocs) }
                let fromInterval = Int(from.timeIntervalSince1970) * 1000
                let toInterval = Int(to.timeIntervalSince1970) * 1000
                return (fromInterval, toInterval)
            }.makeScrappedRequest(.get, url: {  (_, values) -> URL in
                let subpath = "chartscalendar/events/\(epic.rawValue)/from/\(values.from)/to/\(values.to)/"
                return rootURL.appendingPathComponent(subpath)
            }, queries: { _ in
                [.init(name: "ssoToken", value: scrappedCredentials.security),
                 .init(name: "locale", value: Locale.london.identifier),
                 .init(name: "eventType", value: "ECONOMIC_CALENDAR")]
            }, headers: { (_, _) in
                [.clientSessionToken: scrappedCredentials.cst,
                 .securityToken: scrappedCredentials.security,
                 .pragma: "no-cache",
                 .cacheControl: "no-cache"]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(API.Error.transform)
            .eraseToAnyPublisher()
    }
}

extension API {
    /// Economic calendar with economic *happenings*.
    public enum Calendar {
        /// An economic event that has heppened or is targeted to happen.
        public struct Event: Decodable {
            /// The specific date and time when the economic event is happening.
            public let date: Date
            /// The country code.
            public let country: Country
            /// The title of the economic event.
            public let headline: String
            /// The previous recurring event value.
            public let previous: Self.Value?
            /// The expected recurring event value.
            public let expected: Self.Value?
            /// The actual recurring event value.
            public let actual: Self.Value?
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: _CodingKeys.self)
                
                let timestamp = try container.decode(Int.self, forKey: .date)
                self.date = Date(timeIntervalSince1970: Double(timestamp / 1000))
                self.country = try container.decode(Country.self, forKey: .country)
                self.headline = try container.decode(String.self, forKey: .headline)
                
                let nestedContainer = try container.nestedContainer(keyedBy: _CodingKeys.DataKeys.self, forKey: .data)
                self.previous = try nestedContainer.decodeIfPresent(Self.Value.self, forKey: .previous)
                self.expected = try nestedContainer.decodeIfPresent(Self.Value.self, forKey: .expected)
                self.actual = try nestedContainer.decodeIfPresent(Self.Value.self, forKey: .actual)
            }
            
            private enum _CodingKeys: String, CodingKey {
                case type
                case date = "timestamp"
                case headline
                case country = "countryCode"
                case data = "eventTypeData"
                
                enum DataKeys: String, CodingKey {
                    case previous = "previousValue"
                    case expected = "expectedValue"
                    case actual = "actualValue"
                }
            }
        }
    }
}

// MARK: - Functionality

extension API.Calendar.Event {
    /// A calendar event value (usually representing a previous, expected, and actual value).
    public enum Value: Decodable, CustomDebugStringConvertible {
        /// A simple number value.
        case number(Decimal64)
        /// A closed range of values.
        case range(ClosedRange<Decimal64>)
        /// A non-supported values.
        case unknown(String)

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
