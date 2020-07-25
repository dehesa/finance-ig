import Combine
import Foundation
import Decimals

extension API.Request {
    /// List of endpoints related to a user's activity.
    public struct Prices {
        /// Pointer to the actual API instance in charge of calling the endpoints.
        fileprivate unowned let _api: API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        @usableFromInline internal init(api: API) { self._api = api }
    }
}

extension API.Request.Prices {
    
    // MARK: GET /prices/{epic}
    
    /// Returns historical prices for a particular instrument.
    /// - warning: The *constinuous* version of this endpoint is preferred. Depending on the amount of price points requested, this endpoint may take a long time or it may FAIL.
    /// - parameter epic: Instrument's epic (e.g. `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - returns: Publisher forwarding a list of price points and how many more requests (i.e. `allowance`) can still be performed on a unit of time.
    public func get(epic: IG.Market.Epic, from: Date, to: Date = Date(), resolution: API.Price.Resolution = .minute) -> AnyPublisher<(prices: [API.Price], allowance: API.Price.Allowance),IG.Error> {
        self._api.publisher { (api) -> DateFormatter in
                let timezone = try api.channel.credentials?.timezone ?> IG.Error._unfoundCredentials()
                return DateFormatter.iso8601Broad.deepCopy(timeZone: timezone)
            }.makeRequest(.get, "prices/\(epic)", version: 3, credentials: true, queries: { (values) -> [URLQueryItem] in
                [.init(name: "from", value: values.string(from: from)),
                 .init(name: "to", value: values.string(from: to)),
                 .init(name: "resolution", value: resolution.description),
                 .init(name: "pageSize", value: "0"),
                 .init(name: "pageNumber", value: "1") ]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (response: _PagedPrices, _) in
                (response.prices, response.metadata.allowance)
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /prices/{epic}
    
    /// Returns historical prices for a particular instrument.
    ///
    /// **This is a paginated-request**, which means that the returned `Publisher` will forward downstream several value each one with an array (of size `array.size`).
    /// - parameter epic: Instrument's epic (e.g. `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - parameter page: Paging variables for the transactions page received. For the `page.size` and `page.number` must be greater than zero, or the publisher will fail.
    /// - returns: Combine `Publisher` forwarding multiple values. Each value represents a list of price points and how many more requests (i.e. `allowance`) can still be performed on a unit of time.
    public func getContinuously(epic: IG.Market.Epic, from: Date, to: Date = Date(), resolution: API.Price.Resolution = .minute, array page: (size: Int, number: Int) = (20, 1)) -> AnyPublisher<(prices: [API.Price], allowance: API.Price.Allowance),IG.Error> {
        self._api.publisher { (api) -> (pageSize: Int, pageNumber: Int, formatter: DateFormatter) in
                let timezone = try api.channel.credentials?.timezone ?> IG.Error._unfoundCredentials()
                guard page.size > 0 else { throw IG.Error._invalid(pageSize: page.size) }
                guard page.number > 0 else { throw IG.Error._invalid(pageNumber: page.number) }

                let formatter = DateFormatter.iso8601Broad.deepCopy(timeZone: timezone)
                return (page.size, page.number, formatter)
            }.makeRequest(.get, "prices/\(epic)", version: 3, credentials: true, queries: { (values) -> [URLQueryItem] in
                [.init(name: "from", value: values.formatter.string(from: from)),
                 .init(name: "to", value: values.formatter.string(from: to)),
                 .init(name: "resolution", value: resolution.description),
                 .init(name: "pageSize", value: String(values.pageSize)),
                 .init(name: "pageNumber", value: String(values.pageNumber)) ]
            }).sendPaginating(request: { (_, initial, previous) -> URLRequest? in
                guard let previous = previous else { return initial.request }
                guard let pageNumber = previous.metadata.next else { return nil }
                return try initial.request.set { try $0.addQueries([URLQueryItem(name: "pageNumber", value: String(pageNumber))]) }
            }, call: { (publisher, _) in
                publisher.send(expecting: .json, statusCode: 200)
                    .decodeJSON(decoder: .default(response: true)) { (response: _PagedPrices, _) in
                        (response.metadata.page, (response.prices, response.metadata.allowance))
                    }.mapError(errorCast)
            }).mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

extension API.Price {
    /// Resolution of requested prices.
    public enum Resolution: CaseIterable, CustomStringConvertible {
        case second
        case minute, minute2, minute3, minute5, minute10, minute15, minute30
        case hour, hour2, hour3, hour4
        case day, week, month
        
        /// Creates a resolution from the available ones closest to the amount of seconds passed as argument.
        /// - parameter seconds: Amount of seconds desired for a resolution.
        public init(seconds: Int) {
            var result: (resolution: Self, distance: Int) = (.second, .max)
            
            for resolution in Self.allCases {
                let distance = abs(resolution.seconds - seconds)
                guard result.distance > distance else {
                    self = result.resolution; return
                }
                result = (resolution, distance)
            }
            
            self = result.resolution
        }
        
        public var description: String {
            switch self {
            case .second: return "SECOND"
            case .minute: return "MINUTE"
            case .minute2: return "MINUTE_2"
            case .minute3: return "MINUTE_3"
            case .minute5: return "MINUTE_5"
            case .minute10: return "MINUTE_10"
            case .minute15: return "MINUTE_15"
            case .minute30: return "MINUTE_30"
            case .hour: return "HOUR"
            case .hour2: return "HOUR_2"
            case .hour3: return "HOUR_3"
            case .hour4: return "HOUR_4"
            case .day: return "DAY"
            case .week: return "WEEK"
            case .month: return "MONTH"
            }
        }
        
        /// Returns the number of seconds of the receiving resolution.
        public var seconds: Int {
            switch self {
            case .second: return 1
            case .minute: return 60
            case .minute2: return 120
            case .minute3: return 180
            case .minute5: return 300
            case .minute10: return 600
            case .minute15: return 900
            case .minute30: return 1800
            case .hour: return 3_600
            case .hour2: return 7_200
            case .hour3: return 10_800
            case .hour4: return 14_400
            case .day: return 86_400
            case .week: return 604_800
            case .month: return 2_592_000
            }
        }
    }
}

extension API.Request.Prices {
    /// Single page of prices request.
    private struct _PagedPrices: Decodable {
        let instrumentType: API.Market.Instrument.Kind
        let prices: [API.Price]
        let metadata: Self.Metadata
        
        struct Metadata: Decodable {
            let allowance: API.Price.Allowance
            let page: Self.Page
            /// The total amount of price points after all pages have been loaded.
            let totalCount: UInt
            
            private enum CodingKeys: String, CodingKey {
                case allowance, page = "pageData", totalCount = "size"
            }
            
            struct Page: Decodable {
                /// The total amount (maximum) of price points that the current page can hold.
                let size: Int
                /// The page number.
                let number: Int
                /// The total number of pages.
                let count: Int
                /// Returns the next page number if there are more to go (`nil` otherwise).
                var next: Int? { return (number < count) ? number + 1 : nil }
                
                private enum CodingKeys: String, CodingKey {
                    case size = "pageSize", number = "pageNumber", count = "totalPages"
                }
            }
        }
    }
}

private extension IG.Error {
    /// Error raised when the API credentials haven't been found.
    static func _unfoundCredentials() -> Self {
        Self(.api(.invalidRequest), "No credentials were found on the API instance.", help: "Log in before calling this request.")
    }
    /// Error raised when the page size is an invalid number.
    static func _invalid(pageSize: Int) -> Self {
        Self(.api(.invalidRequest), "The page size must be greater than zero.", help: "Read the request documentation and be sure to follow all requirements.", info: ["Page size": pageSize])
    }
    /// Error raised when the page number is an invalid number.
    static func _invalid(pageNumber: Int) -> Self {
        Self(.api(.invalidRequest), "The page number must be greater than zero.", help: "Read the request documentation and be sure to follow all requirements.", info: ["Page number": pageNumber])
    }
}
