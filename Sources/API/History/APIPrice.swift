import ReactiveSwift
import Foundation

extension API {
    /// Returns historical prices for a particular instrument.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - parameter page: Paging variables for the transactions page received. If `nil`, paging is disabled.
    /// - todo: The request may accept a further `max` option specifying the maximum amount of price points that should be loaded if a data range hasn't been given.
    public func prices(epic: String, from: Date, to: Date = Date(), resolution: API.Request.Price.Resolution = .minute, page: (size: UInt, number: UInt)? = (20, 1)) -> SignalProducer<API.Response.SnapshotPrices,API.Error> {
        return SignalProducer(api: self, validating: { (api) -> (pageSize: UInt, pageNumber: UInt, formatter: Foundation.DateFormatter) in
                guard !epic.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The provided epic for price query is empty.")
                }
            
                guard let timezone = api.session.credentials?.timezone else {
                    throw API.Error.invalidCredentials(nil, message: "No credentials found")
                }
            
                let formatter = API.DateFormatter.deepCopy(API.DateFormatter.iso8601NoTimezone)
                formatter.timeZone = timezone
            
                guard let page = page else {
                    return (0, 1, formatter)
                }
            
                let pageNumber = (page.number > 0) ? page.number : 1
                return (page.size, pageNumber, formatter)
            }).request(.get, "prices/\(epic)", version: 3, credentials: true, queries: { (_,validated) in
                return [URLQueryItem(name: "from", value: validated.formatter.string(from: from)),
                        URLQueryItem(name: "to", value: validated.formatter.string(from: to)),
                        URLQueryItem(name: "resolution", value: resolution.rawValue),
                        URLQueryItem(name: "pageSize", value: String(validated.pageSize)),
                        URLQueryItem(name: "pageNumber", value: String(validated.pageNumber)) ]
            }).paginate(request: { (api, initialRequest, previous) in
                guard let previous = previous else {
                    return initialRequest
                }
                
                guard let pageNumber = previous.meta.next else {
                    return nil
                }
                
                var request = initialRequest
                try request.addQueries( [URLQueryItem(name: "pageNumber", value: String(pageNumber))] )
                return request
            }, endpoint: { (producer) -> SignalProducer<(API.Response.PagedPrices.Metadata.Page,API.Response.SnapshotPrices), API.Error> in
                producer.send(expecting: .json)
                    .validateLadenData(statusCodes: [200])
                    .decodeJSON()
                    .map { (response: API.Response.PagedPrices) in
                        let result = API.Response.SnapshotPrices(prices: response.prices, allowance: response.metadata.allowance)
                        return (response.metadata.page, result)
                    }
            })
    }
}

// MARK: -

extension API.Request {
    /// Price request properties.
    public enum Price {
        /// Resolution of requested prices.
        public enum Resolution: String, CaseIterable {
            case second = "SECOND"
            case minute = "MINUTE", minutes2 = "MINUTE_2", minutes3 = "MINUTE_3", minutes5 = "MINUTE_5", minutes10 = "MINUTE_10", minutes15 = "MINUTE_15", minutes30 = "MINUTE_30"
            case hour = "HOUR", hours2 = "HOUR_2", hours3 = "HOUR_3", hours4 = "HOUR_4"
            case day = "DAY", week = "WEEK", month = "MONTH"
            
            /// Creates a resolution from the available ones closest to the amount of seconds passed as argument.
            /// - parameter seconds: Amount of seconds desired for a resolution.
            public init(seconds: Int) {
                var result: (resolution: Resolution, distance: Int) = (.second, .max)
                
                for resolution in Resolution.allCases {
                    let distance = abs(resolution.seconds - seconds)
                    guard result.distance > distance else {
                        self = result.resolution; return
                    }
                    
                    result = (resolution, distance)
                }
                
                self = result.resolution
            }
            
            /// Returns the number of seconds of the receiving resolution.
            public var seconds: Int {
                switch self {
                case .second: return 1
                case .minute: return 60
                case .minutes2: return 120
                case .minutes3: return 180
                case .minutes5: return 300
                case .minutes10: return 600
                case .minutes15: return 900
                case .minutes30: return 1800
                case .hour: return 3_600
                case .hours2: return 7_200
                case .hours3: return 10_800
                case .hours4: return 14_400
                case .day: return 86_400
                case .week: return 604_800
                case .month: return 2_592_000
                }
            }
        }
    }
}

// MARK: -

extension API.Response {
    /// Single page of prices request.
    fileprivate struct PagedPrices: Decodable {
        /// Instrument type.
        let instrumentType: API.Instrument.Kind
        /// Past market prices.
        let prices: [API.Response.Price]
        /// Metadata information about the current request.
        let metadata: API.Response.PagedPrices.Metadata
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
}

extension API.Response {
    /// Group of requested prices and further price request allowance.
    public struct SnapshotPrices {
        /// Past market prices.
        public let prices: [API.Response.Price]
        /// Historical price data allowance.
        public let allowance: API.Response.Price.Allowance
    }
}

extension API.Response.PagedPrices {
    /// Page's extra information.
    fileprivate struct Metadata: Decodable {
        /// Historical price data allowance.
        let allowance: API.Response.Price.Allowance
        /// Variables related to the current page.
        let page: Page
        /// The total amount of price points after all pages have been loaded.
        let totalCount: UInt
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        private enum CodingKeys: String, CodingKey {
            case allowance
            case page = "pageData"
            case totalCount = "size"
        }
        
        /// Variables for the current page.
        struct Page: Decodable {
            /// The total amount (maximum) of price points that the current page can hold.
            let size: Int
            /// The page number.
            let number: Int
            /// The total number of pages.
            let count: Int
            
            /// Returns the next page number if there are more to go (`nil` otherwise).
            var next: Int? { return (number < count) ? number + 1 : nil }
            
            /// Do not call! The only way to initialize is through `Decodable`.
            private init?() { fatalError("Unaccessible initializer") }
            
            private enum CodingKeys: String, CodingKey {
                case size = "pageSize"
                case number = "pageNumber"
                case count = "totalPages"
            }
        }
    }
}

extension API.Response {
    /// Historical market price snapshot.
    public struct Price: Decodable {
        /// Highest price.
        let highest: Point
        /// Lowest price.
        let lowest: Point
        /// Open session price.
        let open: Point
        /// Close session price.
        let close: Point
        /// Last traded volume.
        ///
        /// This will generally be `nil` for non exchange traded instrument.
        let lastTradedVolume: UInt?
        /// Snapshot date.
        let snapshotDate: Date
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.open = try container.decode(Point.self, forKey: .open)
            self.close = try container.decode(Point.self, forKey: .close)
            self.highest = try container.decode(Point.self, forKey: .highest)
            self.lowest = try container.decode(Point.self, forKey: .lowest)
            self.lastTradedVolume = try container.decodeIfPresent(UInt.self, forKey: .lastTradedVolume)
            self.snapshotDate = try container.decode(Date.self, forKey: .snapshotDate, with: API.DateFormatter.iso8601NoTimezone)
        }
        
        private enum CodingKeys: String, CodingKey {
            case close = "closePrice"
            case highest = "highPrice"
            case lastTradedVolume
            case lowest = "lowPrice"
            case open = "openPrice"
            case snapshotDate = "snapshotTimeUTC"
        }
    }
}

extension API.Response.Price {
    /// Price Snap.
    public struct Point: Decodable {
        /// Ask price (i.e. buy price).
        public let ask: Double
        /// Bid price (i.e. sell price).
        public let bid: Double
        /// Last traded price.
        ///
        /// This will generally be `nil` for non-exchanged-traded instruments.
        public let lastTraded: Double?
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
}

extension API.Response.Price {
    /// Request allowance for prices.
    public struct Allowance: Decodable {
        /// The date in which the current allowance period will end and the remaining allowance field is reset.
        public let resetDate: Date
        /// The number of data points still available to fetch within the current allowance period.
        public let remaining: Int
        /// The number of data points the API key and account combination is allowed to fetch in any given allowance period.
        public let total: Int
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let numSeconds = try container.decode(TimeInterval.self, forKey: .seconds)
            if let response = decoder.userInfo[.responseHeader] as? HTTPURLResponse,
               let dateString = response.allHeaderFields[API.HTTP.Header.Key.date] as? String,
               let date = API.DateFormatter.humanReadableLong.date(from: dateString) {
                self.resetDate = date.addingTimeInterval(numSeconds)
            } else {
                self.resetDate = Date(timeIntervalSinceNow: numSeconds)
            }
            
            self.remaining = try container.decode(Int.self, forKey: .remainingDataPoints)
            self.total = try container.decode(Int.self, forKey: .totalDataPoints)
        }
        
        private enum CodingKeys: String, CodingKey {
            case seconds = "allowanceExpiry"
            case remainingDataPoints = "remainingAllowance"
            case totalDataPoints = "totalAllowance"
        }
    }
}
