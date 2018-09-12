import ReactiveSwift
import Foundation

extension API {
    /// Returns historical prices for a particular instrument.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - parameter page: Paging variables fro the transactions page received. If `nil`, paging is disabled.
    public func prices(epic: String, from: Date, to: Date = Date(), resolution: API.Request.Price.Resolution = .minute, page: (size: Int, number: Int)? = (20, 1)) -> SignalProducer<API.Response.PricesAndAllowance,API.Error> {
        /// Constants reused through this request.
        let request: (method: API.HTTP.Method, version: Int, expectedCodes: [Int]) = (.get, 3, [200])
        /// The type of event expected at the end of this SignalProducer pipeline.
        typealias EventResult = Signal<API.Response.PricesAndAllowance,API.Error>.Event
        
        /// Generates an `URLRequest` from the function parameters.
        let requestGenerator: (_ api: API, _ pageNumber: Int) throws -> URLRequest = { (api, pageNumber) in
            /// Beginning of error message.
            let errorBlurb = "Prices retrieval failed!"
            guard !epic.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The epic string identifier cannot be empty.") }
            let absoluteURL = api.rootURL.appendingPathComponent("prices/\(epic)")
            
            guard var components = URLComponents(url: absoluteURL, resolvingAgainstBaseURL: true) else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The URL \"\(absoluteURL)url\" cannot be transformed into URL components.")
            }
            
            let pageSize = page?.size ?? 0
            var queries = [URLQueryItem(name: "from", value: API.DateFormatter.iso8601NoTimezone.string(from: from)),
                           URLQueryItem(name: "to", value: API.DateFormatter.iso8601NoTimezone.string(from: to)),
                           URLQueryItem(name: "resolution", value: resolution.rawValue),
                           URLQueryItem(name: "pageSize", value: String(pageSize))]
            if pageSize > 0 {
                guard pageNumber > 0 else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The request's page number cannot be a negative number.")
                }
                queries.append(URLQueryItem(name: "pageNumber", value: String(pageNumber)))
            } else if pageSize < 0 {
                throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The request's page size cannot be a negative number.")
            }
            
            components.queryItems = queries
            
            guard let url = components.url else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The URL couldn't be formed")
            }
            
            return try URLRequest(url: url).set {
                $0.setMethod(request.method)
                $0.addHeaders(version: request.version, credentials: try api.credentials())
            }
        }
        
        return self.paginatedRequest(request: { (api) in
            return try requestGenerator(api, page?.number ?? 1)
        }, expectedStatusCodes: request.expectedCodes) { (api: API, page: API.Response.PagedPrices) -> ([EventResult],URLRequest?) in
            guard !page.prices.isEmpty else {
                return ([.completed], nil)
            }
            
            let value: EventResult = .value((page.prices, page.metadata.allowance))
            guard let nextNumber = page.metadata.page.next else {
                return ([value, .completed], nil)
            }
            
            do {
                let request = try requestGenerator(api, nextNumber)
                return ([value], request)
            } catch let error {
                return ([value, .failed(error as! API.Error)], nil)
            }
        }
    }
}

extension API.Request {
    /// Price request properties.
    public enum Price {
        /// Resolution of requested prices.
        public enum Resolution: String, CaseIterable {
            case second = "SECOND"
            case minute = "MINUTE"
            case minutes2 = "MINUTE_2"
            case minutes3 = "MINUTE_3"
            case minutes5 = "MINUTE_5"
            case minutes10 = "MINUTE_10"
            case minutes15 = "MINUTE_15"
            case minutes30 = "MINUTE_30"
            case hour = "HOUR"
            case hours2 = "HOUR_2"
            case hours3 = "HOUR_3"
            case hours4 = "HOUR_4"
            case day = "DAY"
            case week = "WEEK"
            case month = "MONTH"
            
            public init(seconds: Int) {
                var result: (resolution: Resolution, distance: Int) = (Resolution.second, Int.max)
                
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

extension API.Response {
    /// Single page of prices request.
    internal struct PagedPrices: Decodable {
        /// Instrument type.
        public let instrumentType: API.Instrument.Kind
        /// Past market prices.
        public let prices: [API.Response.Price]
        /// Metadata information about the current request.
        public let metadata: Metadata
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        /// Page's extra information.
        internal struct Metadata: Decodable {
            /// Historical price data allowance.
            let allowance: API.Response.Price.Allowance
            /// Variables related to the current page.
            let page: Page
            
            /// Do not call! The only way to initialize is through `Decodable`.
            private init?() { fatalError("Unaccessible initializer") }
            
            private enum CodingKeys: String, CodingKey {
                case allowance
                case page = "pageData"
            }
            
            /// Variables for the current page.
            internal struct Page: Decodable {
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
    
    /// Simple tuple wrapping the prices response and the HTTP query allowance that it can still be used.
    public typealias PricesAndAllowance = (prices: [API.Response.Price], allowance: API.Response.Price.Allowance)
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
        let ask: Double
        /// Bid price (i.e. sell price).
        let bid: Double
        /// Last traded price.
        ///
        /// This will generally be `nil` for non-exchanged-traded instruments.
        let lastTraded: Double?
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
    
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
