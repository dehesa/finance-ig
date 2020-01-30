import Combine
import Foundation

extension IG.API.Request {
    /// List of endpoints related to a user's activity.
    public struct Price {
        /// Pointer to the actual API instance in charge of calling the endpoints.
        fileprivate unowned let api: IG.API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        init(api: IG.API) { self.api = api }
    }
}

extension IG.API.Request.Price {
    
    // MARK: GET /prices/{epic}
    
    /// Returns historical prices for a particular instrument.
    /// - warning: The *constinuous* version of this endpoint is preferred. Depending on the amount of price points requested, this endpoint may take a long time or it may FAIL.
    /// - parameter epic: Instrument's epic (e.g. `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - returns: *Future* forwarding a list of price points and how many more requests (i.e. `allowance`) can still be performed on a unit of time.
    public func get(epic: IG.Market.Epic, from: Date, to: Date = Date(), resolution: IG.API.Price.Resolution = .minute) -> IG.API.Publishers.Discrete<(prices: [IG.API.Price], allowance: IG.API.Price.Allowance)> {
        api.publisher { (api) -> DateFormatter in
            guard let timezone = api.channel.credentials?.timezone else {
                    throw IG.API.Error.invalidRequest(.noCredentials, suggestion: .logIn)
                }
                return IG.API.Formatter.iso8601Broad.deepCopy(timeZone: timezone)
            }.makeRequest(.get, "prices/\(epic.rawValue)", version: 3, credentials: true, queries: { (values) -> [URLQueryItem] in
                [.init(name: "from", value: values.string(from: from)),
                 .init(name: "to", value: values.string(from: to)),
                 .init(name: "resolution", value: resolution.rawValue),
                 .init(name: "pageSize", value: "0"),
                 .init(name: "pageNumber", value: "1") ]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (response: Self.PagedPrices, _) in
                (response.prices, response.metadata.allowance)
            }.mapError(IG.API.Error.transform)
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
    public func getContinuously(epic: IG.Market.Epic, from: Date, to: Date = Date(), resolution: IG.API.Price.Resolution = .minute, array page: (size: Int, number: Int) = (20, 1)) -> IG.API.Publishers.Continuous<(prices: [IG.API.Price], allowance: IG.API.Price.Allowance)> {
        api.publisher { (api) -> (pageSize: Int, pageNumber: Int, formatter: DateFormatter) in
                guard let timezone = api.channel.credentials?.timezone else {
                    throw IG.API.Error.invalidRequest(.noCredentials, suggestion: .logIn)
                }
                guard page.size > 0 else {
                    throw IG.API.Error.invalidRequest(.init(#"The page size must be greater than zero; however, "\#(page.size)" was provided instead"#), suggestion: .readDocs)
                }
                guard page.number > 0 else {
                    throw IG.API.Error.invalidRequest(.init(#"The page number must be greater than zero; however, "\#(page.number)" was provided instead"#), suggestion: .readDocs)
                }

                let formatter = IG.API.Formatter.iso8601Broad.deepCopy(timeZone: timezone)
                return (page.size, page.number, formatter)
            }.makeRequest(.get, "prices/\(epic.rawValue)", version: 3, credentials: true, queries: { (values) -> [URLQueryItem] in
                [.init(name: "from", value: values.formatter.string(from: from)),
                 .init(name: "to", value: values.formatter.string(from: to)),
                 .init(name: "resolution", value: resolution.rawValue),
                 .init(name: "pageSize", value: String(values.pageSize)),
                 .init(name: "pageNumber", value: String(values.pageNumber)) ]
            }).sendPaginating(request: { (_, initial, previous) -> URLRequest? in
                guard let previous = previous else { return initial.request }
                guard let pageNumber = previous.metadata.next else { return nil }
                return try initial.request.set { try $0.addQueries([URLQueryItem(name: "pageNumber", value: String(pageNumber))]) }
            }, call: { (publisher, _) in
                publisher.send(expecting: .json, statusCode: 200)
                    .decodeJSON(decoder: .default(response: true)) { (response: Self.PagedPrices, _) in
                        (response.metadata.page, (response.prices, response.metadata.allowance))
                    }.mapError(IG.API.Error.transform)
            }).mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.API.Price {
    /// Resolution of requested prices.
    public enum Resolution: String, CaseIterable {
        case second = "SECOND"
        case minute = "MINUTE", minute2 = "MINUTE_2", minute3 = "MINUTE_3", minute5 = "MINUTE_5", minute10 = "MINUTE_10", minute15 = "MINUTE_15", minute30 = "MINUTE_30"
        case hour = "HOUR", hour2 = "HOUR_2", hour3 = "HOUR_3", hour4 = "HOUR_4"
        case day = "DAY", week = "WEEK", month = "MONTH"
        
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

extension IG.API.Request.Price {
    /// Single page of prices request.
    private struct PagedPrices: Decodable {
        let instrumentType: IG.API.Market.Instrument.Kind
        let prices: [IG.API.Price]
        let metadata: Self.Metadata
        
        struct Metadata: Decodable {
            let allowance: IG.API.Price.Allowance
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

extension IG.API {
    /// Historical market price snapshot.
    public struct Price: Decodable, Equatable {
        /// Snapshot date.
        public let date: Date
        /// Open session price.
        public let open: Self.Point
        /// Close session price.
        public let close: Self.Point
        /// Lowest price.
        public let lowest: Self.Point
        /// Highest price.
        public let highest: Self.Point
        /// Last traded volume.
        ///
        /// This will generally be `nil` for non exchange traded instrument.
        public let volume: UInt?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.date = try container.decode(Date.self, forKey: .date, with: IG.API.Formatter.iso8601Broad)
            self.open = try container.decode(Self.Point.self, forKey: .open)
            self.close = try container.decode(Self.Point.self, forKey: .close)
            self.highest = try container.decode(Self.Point.self, forKey: .highest)
            self.lowest = try container.decode(Self.Point.self, forKey: .lowest)
            self.volume = try container.decodeIfPresent(UInt.self, forKey: .volume)
        }
        
        /// Designated initalizer.
        internal init(date: Date, open: Self.Point, close: Self.Point, lowest: Self.Point, highest: Self.Point, volume: UInt?) {
            self.date = date
            self.open = open
            self.close = close
            self.lowest = lowest
            self.highest = highest
            self.volume = volume
        }
        
        public static func == (lhs: API.Price, rhs: API.Price) -> Bool {
            return (lhs.date == rhs.date) &&
                   (lhs.open == rhs.open) && (lhs.close == rhs.close) &&
                   (lhs.lowest == rhs.lowest) && (lhs.highest == rhs.highest) &&
                   (lhs.volume == rhs.volume)
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

extension IG.API.Price {
    /// Price Snap.
    public struct Point: Decodable, Equatable {
        /// Bid price (i.e. the price being offered  to buy an asset).
        public let bid: Decimal
        /// Ask price (i.e. the price being asked to sell an asset).
        public let ask: Decimal
        /// Last traded price.
        ///
        /// This will generally be `nil` for non-exchanged-traded instruments.
        public let lastTraded: Decimal?
        
        /// Designated initalizer.
        internal init(bid: Decimal, ask: Decimal, lastTraded: Decimal? = nil) {
            self.bid = bid
            self.ask = ask
            self.lastTraded = lastTraded
        }
        
        /// The middle price between the *bid* and the *ask* price.
        public var mid: Decimal {
            return self.bid + 0.5 * (self.ask - self.bid)
        }
    }
}

extension IG.API.Price {
    /// Request allowance for prices.
    public struct Allowance: Decodable {
        /// The date in which the current allowance period will end and the remaining allowance field is reset.
        public let resetDate: Date
        /// The number of data points still available to fetch within the current allowance period.
        public let remaining: UInt
        /// The number of data points the API key and account combination is allowed to fetch in any given allowance period.
        public let total: UInt
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            guard let response = decoder.userInfo[IG.API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse else {
                let ctx = DecodingError.Context(codingPath: container.codingPath, debugDescription: #"The request/response values stored in the JSONDecoder "userInfo" couldn't be found"#)
                throw DecodingError.valueNotFound(HTTPURLResponse.self, ctx)
            }
            
            guard let dateString = response.allHeaderFields[IG.API.HTTP.Header.Key.date.rawValue] as? String,
                  let date = IG.API.Formatter.humanReadableLong.date(from: dateString) else {
                let message = "The date on the response header couldn't be processed"
                throw DecodingError.dataCorruptedError(forKey: .seconds, in: container, debugDescription: message)
            }
            
            let numSeconds = try container.decode(TimeInterval.self, forKey: .seconds)
            self.resetDate = date.addingTimeInterval(numSeconds)
            
            self.remaining = try container.decode(UInt.self, forKey: .remainingDataPoints)
            self.total = try container.decode(UInt.self, forKey: .totalDataPoints)
        }
        
        private enum CodingKeys: String, CodingKey {
            case seconds = "allowanceExpiry"
            case remainingDataPoints = "remainingAllowance"
            case totalDataPoints = "totalAllowance"
        }
    }
}

// MARK: - Functionality

extension IG.API.Price: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("date", self.date, formatter: IG.API.Formatter.timestamp.deepCopy(timeZone: .current))
        result.append("open", Self.represent(self.open))
        result.append("close", Self.represent(self.close))
        result.append("lowest", Self.represent(self.lowest))
        result.append("highest", Self.represent(self.highest))
        result.append("volume", self.volume)
        return result.generate()
    }
    
    private static func represent(_ point: Self.Point) -> String {
        return "\(point.ask) ask, \(point.bid) bid"
    }
}

extension IG.API.Price.Allowance: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("reset date", self.resetDate, formatter: IG.API.Formatter.timestamp.deepCopy(timeZone: .current))
        result.append("data points (remaining)", self.remaining)
        result.append("data points (total)", self.total)
        return result.generate()
    }
}
