import ReactiveSwift
import Foundation

extension API.Request.Price {
    
    // MARK: GET /prices/{epic}
    
    /// Returns historical prices for a particular instrument.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - parameter page: Paging variables for the transactions page received. If `nil`, paging is disabled.
    /// - todo: The request may accept a further `max` option specifying the maximum amount of price points that should be loaded if a data range hasn't been given.
    public func get(epic: String, from: Date, to: Date = Date(), resolution: API.Request.Price.Resolution = .minute, page: (size: UInt, number: UInt)? = (20, 1)) -> SignalProducer<(prices: [API.Price], allowance: API.Price.Allowance),API.Error> {
        return SignalProducer(api: self.api, validating: { (api) -> (pageSize: UInt, pageNumber: UInt, formatter: Foundation.DateFormatter) in
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
            }, endpoint: { (producer) -> SignalProducer<(PagedPrices.Metadata.Page, (prices: [API.Price], allowance: API.Price.Allowance)), API.Error> in
                producer.send(expecting: .json)
                    .validateLadenData(statusCodes: 200)
                    .decodeJSON { (request, response) -> JSONDecoder in
                        guard let dateString = response.allHeaderFields[API.HTTP.Header.Key.date.rawValue] as? String,
                              let date = API.DateFormatter.humanReadableLong.date(from: dateString) else {
                            throw API.Error.invalidResponse(response, request: request, data: nil, underlyingError: nil, message: "The response date couldn't be inferred.")
                        }
                        
                        let decoder = JSONDecoder()
                        decoder.userInfo[API.JSON.DecoderKey.responseDate] = date
                        return decoder
                    }.map { (response: PagedPrices) in
                        let result = (response.prices, allowance: response.metadata.allowance)
                        return (response.metadata.page, result)
                    }
            })
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to price history.
    public struct Price {
        /// Pointer to the actual API instance in charge of calling the endpoints.
        fileprivate unowned let api: API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        init(api: API) {
            self.api = api
        }
    }
}

// MARK: Request Entities

extension API.Request.Price {
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

// MARK: Response Entities

extension API.Request.Price {
    /// Single page of prices request.
    private struct PagedPrices: Decodable {
        let instrumentType: API.Instrument.Kind
        let prices: [API.Price]
        let metadata: Metadata
        
        struct Metadata: Decodable {
            let allowance: API.Price.Allowance
            let page: Page
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

extension API {
    /// Historical market price snapshot.
    public struct Price: Decodable {
        /// Snapshot date.
        let date: Date
        /// Open session price.
        let open: Point
        /// Close session price.
        let close: Point
        /// Lowest price.
        let lowest: Point
        /// Highest price.
        let highest: Point
        /// Last traded volume.
        ///
        /// This will generally be `nil` for non exchange traded instrument.
        let volume: UInt?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.date = try container.decode(Date.self, forKey: .date, with: API.DateFormatter.iso8601NoTimezone)
            self.open = try container.decode(Point.self, forKey: .open)
            self.close = try container.decode(Point.self, forKey: .close)
            self.highest = try container.decode(Point.self, forKey: .highest)
            self.lowest = try container.decode(Point.self, forKey: .lowest)
            self.volume = try container.decodeIfPresent(UInt.self, forKey: .volume)
        }
        
        private enum CodingKeys: String, CodingKey {
            case date = "snapshotTimeUTC"
            case open = "openPrice"
            case close = "closePrice"
            case highest = "highPrice"
            case lowest = "lowPrice"
            case volume = "lastTradedVolume"
        }
    }
}

extension API.Price {
    /// Price Snap.
    public struct Point: Decodable {
        /// Bid price (i.e. the price being offered  to buy an asset).
        public let bid: Double
        /// Ask price (i.e. the price being asked to sell an asset).
        public let ask: Double
        /// Last traded price.
        ///
        /// This will generally be `nil` for non-exchanged-traded instruments.
        public let lastTraded: Double?
        
        /// The middle price between the *bid* and the *ask* price.
        public var mid: Double {
            return bid + 0.5 * (ask - bid)
        }
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
}

extension API.Price {
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
            guard let date = decoder.userInfo[API.JSON.DecoderKey.responseDate] as? Date else {
                throw DecodingError.dataCorruptedError(forKey: .seconds, in: container, debugDescription: "The JSON decoder didn't have the response date in its userinfo property.")
            }
            self.resetDate = date.addingTimeInterval(numSeconds)
            
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
