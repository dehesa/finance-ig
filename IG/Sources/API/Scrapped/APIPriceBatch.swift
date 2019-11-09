import Combine
import Foundation

extension IG.API.Request.Scrapped {
    
    // MARK: GET /chart/snapshot
    
    /// Returns a market snapshot for the given epic.
    ///
    /// The information retrieved is used to form charts on the IG platform.
    /// - parameter epic: Instrument's epic (e.g. `CS.D.EURUSD.MINI.IP`).
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - parameter numDataPoints: The number of data points to receive on the prices array result.
    /// - parameter rootURL: The URL used as the based for all scrapped endpoints.
    /// - parameter scrappedCredentials: The credentials used to called endpoints from the IG's website.
    public func getPriceSnapshot(epic: IG.Market.Epic, resolution: IG.API.Price.Resolution, numDataPoints: Int, rootURL: URL = IG.API.scrappedRootURL, scrappedCredentials: (cst: String, security: String)) -> IG.API.Publishers.Discrete<IG.API.PriceSnapshot> {
        self.api.publisher
            .makeScrappedRequest(.get, url: { (_, _) in
                let interval = resolution.components
                let subpath = "chart/snapshot/\(epic.rawValue)/\(interval.number)/\(interval.identifier)/combined-cached/\(numDataPoints)"
                return rootURL.appendingPathComponent(subpath)
            }, queries: { _ in
                [.init(name: "format", value: "json"),
                .init(name: "locale", value: Locale.ig.identifier),
                .init(name: "delay", value: "0")]
            }, headers: { (_, _) in
                [.clientSessionToken: scrappedCredentials.cst,
                .securityToken: scrappedCredentials.security,
                .pragma: "no-cache",
                .cacheControl: "no-cache"]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /chart/snapshot
    
    /// - warning: Be mindful of the amount of data being requested. There is a maximum for each interval that can be requested.
    /// - parameter epic: Instrument's epic (e.g. `CS.D.EURUSD.MINI.IP`).
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - parameter scalingFactor: The factor to be applied to every single data point returned.
    /// - parameter rootURL: The URL used as the based for all scrapped endpoints.
    /// - parameter scrappedCredentials: The credentials used to called endpoints from the IG's website.
    /// - returns: Sorted array (from past to present) with `numDataPoints` price data points.
    public func getPrices(epic: IG.Market.Epic, resolution: IG.API.Price.Resolution, from: Date, to: Date, scalingFactor: Decimal, rootURL: URL = IG.API.scrappedRootURL, scrappedCredentials: (cst: String, security: String)) -> IG.API.Publishers.Discrete<[IG.API.Price]> {
        self.api.publisher { _ -> (from: DateComponents, to: DateComponents) in
                guard from <= to else { throw IG.API.Error.invalidRequest(#"The "from" date must occur before the "to" date"#, suggestion: .readDocs) }
                let fromComponents = UTC.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: from)
                let toComponents = UTC.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: to)
                return (fromComponents, toComponents)
            }.makeScrappedRequest(.get, url: { (_, values) in
                let interval = resolution.components
                let (f, t) = values
                let subpath = "chart/snapshot/\(epic.rawValue)/\(interval.number)/\(interval.identifier)/batch/start/\(f.year!)/\(f.month!)/\(f.day!)/\(f.hour!)/\(f.minute!)/\(f.second!)/\(min(f.nanosecond!, 999))/end/\(t.year!)/\(t.month!)/\(t.day!)/\(t.hour!)/\(t.minute!)/\(t.second!)/\(min(t.nanosecond!,999))"
                return rootURL.appendingPathComponent(subpath)
            }, queries: { _ in
                [.init(name: "format", value: "json"),
                 .init(name: "locale", value: Locale.ig.identifier)]
            }, headers: { (_, _) in
                [.clientSessionToken: scrappedCredentials.cst,
                 .securityToken: scrappedCredentials.security,
                 .pragma: "no-cache",
                 .cacheControl: "no-cache"]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .custom({ (_, _, _) in JSONDecoder().set { $0.userInfo[.scalingFactor] = scalingFactor } })) { (response: IG.API.Market.ScrappedBatch, _) in
                response.prices
            }.mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

extension IG.API {
    /// Market snapshot retrieved from a scrapped endpoint.
    public struct PriceSnapshot: Decodable {
        /// The epic identifying the market.
        public let epic: IG.Market.Epic
        /// The market's name.
        public let name: String
        /// The locale used to express numbers.
        public let locale: Locale
        /// Number of decimal positions for pip representation.
        public let decimalPlaces: Decimal
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Decimal
        /// Boolean indicating whether the price data point values has been scaled.
        ///
        /// The prices displayed by this structure are "real" and don't require any further processing; however, this boolean indicates whether other scrapped endpoints returned scaled values.
        public let isScaled: Bool
        /// Boolean indicating whether the snapshot prices are delayed.
        public let delay: Int
        /// The time offset from UTC.
        public let offsetToUTC: TimeInterval
        /// The price data points available throught the batch endpoint.
        public let availableBatchPrices: ClosedRange<Date>
        /// The prices brought with the snapshot (already ordered by the server).
        public let prices: [IG.API.Price]
        
        public init(from decoder: Decoder) throws {
            let topContainer = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            let instrumentContainer = try topContainer.nestedContainer(keyedBy: Self.CodingKeys.InstrumentKeys.self, forKey: .instrument)
            self.epic = try instrumentContainer.decode(IG.Market.Epic.self, forKey: .epic)
            self.name = try instrumentContainer.decode(String.self, forKey: .name)
            self.locale = Locale(identifier: try instrumentContainer.decode(String.self, forKey: .locale))
            self.scalingFactor = try Decimal(string: try instrumentContainer.decode(String.self, forKey: .scalingFactor)) ?! DecodingError.dataCorruptedError(forKey: .scalingFactor, in: instrumentContainer, debugDescription: "The \"scaling factor\" value cannot be transformed into a numeric value")
            self.decimalPlaces = try Decimal(string: try instrumentContainer.decode(String.self, forKey: .decimalPlaces)) ?! DecodingError.dataCorruptedError(forKey: .decimalPlaces, in: instrumentContainer, debugDescription: "The \"decimal places\" value cannot be transformed into a numeric value")
            self.isScaled = try instrumentContainer.decode(Bool.self, forKey: .isScaled)
            self.delay = try instrumentContainer.decode(Int.self, forKey: .delay)
            
            let intervalContainer = try topContainer.nestedContainer(keyedBy: Self.CodingKeys.IntervalKeys.self, forKey: .intervals)
            let start = try intervalContainer.decode(Int.self, forKey: .startTimestamp)
            let end = try intervalContainer.decode(Int.self, forKey: .endTimestamp)
            self.availableBatchPrices = Date(timeIntervalSince1970: Double(start / 1000))...Date(timeIntervalSince1970: Double(end / 1000))
            self.offsetToUTC = try intervalContainer.decode(TimeInterval.self, forKey: .offsetToUTC)
            
            let storageContainer = try topContainer.nestedContainer(keyedBy: Self.CodingKeys.StorageKeys.self, forKey: .storage)
            //let offset: TimeInterval = (try storageContainer.decode(Bool.self, forKey: .isConsolidated)) ? try intervalContainer.decode(TimeInterval.self, forKey: .consolidationTimezoneOffset) : 0
            
            let scalingFactor = (self.isScaled) ? self.scalingFactor : Decimal(1)
            let elementsContainer = try storageContainer.nestedUnkeyedContainer(forKey: .elements)
            self.prices = try Self.decode(scrappedDataPoints: elementsContainer, scalingFactor: scalingFactor)
        }
        
        private enum CodingKeys: String, CodingKey {
            case instrument = "instrumentInfoDto"
            case intervals = "intervalsDto"
            case storage = "intervalsDataPointsDto"
            
            enum InstrumentKeys: String, CodingKey {
                case epic, name, locale = "nameLocale"
                case scalingFactor, decimalPlaces
                case delay, isScaled = "scaled"
            }
            
            enum IntervalKeys: String, CodingKey {
                case startTimestamp, endTimestamp
                case offsetToUTC
                case consolidationTimezoneOffset
            }
            
            enum StorageKeys: String, CodingKey {
                case elements = "intervalsDataPoints"
            }
        }
    }
}

extension IG.API.Market {
    /// A batch of data prices.
    fileprivate struct ScrappedBatch: Decodable {
        /// ???
        let isConsolidated: Bool
        /// The identifier for the given transaction.
        let transactionIdentifier: String
        /// All the data prices.
        let prices: [IG.API.Price]
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.isConsolidated = try container.decode(Bool.self, forKey: .isConsolidated)
            self.transactionIdentifier = try container.decode(String.self, forKey: .transactionIdentifier)
            
            let unkeyedContainer = try container.nestedUnkeyedContainer(forKey: .prices)
            let scalingFactor = try (decoder.userInfo[.scalingFactor] as? Decimal) ?! DecodingError.valueNotFound(Decimal.self, .init(codingPath: container.codingPath, debugDescription: "The userInfo value under key \"\(CodingUserInfoKey.scalingFactor)\" wasn't found or it was invalid"))
            self.prices = try IG.API.PriceSnapshot.decode(scrappedDataPoints: unkeyedContainer, scalingFactor: scalingFactor)
        }
        
        private enum CodingKeys: String, CodingKey {
            case isConsolidated = "consolidated"
            case transactionIdentifier = "transactionId"
            case prices = "intervalsDataPoints"
        }
    }
}

extension IG.API.PriceSnapshot {
    /// Extracted functionality decoding all price data points under a given unkeyed decoding container.
    fileprivate static func decode(scrappedDataPoints: UnkeyedDecodingContainer, scalingFactor: Decimal) throws -> [IG.API.Price] {
        var prices: [IG.API.Price] = []
        
        let decodePoint: (KeyedDecodingContainer<Self.ElementKeys.DataPointKeys>, Self.ElementKeys.DataPointKeys) throws -> API.Price.Point = {
            let pointContainer = try $0.nestedContainer(keyedBy: Self.ElementKeys.DataPointKeys.PriceKeys.self, forKey: $1)
            let bid = try pointContainer.decode(Decimal.self, forKey: .bid) / scalingFactor
            let ask = try pointContainer.decode(Decimal.self, forKey: .ask) / scalingFactor
            return .init(bid: bid, ask: ask, lastTraded: nil)
        }
        
        var elementsContainer = scrappedDataPoints
        while !elementsContainer.isAtEnd {
            var pointsContainer = try elementsContainer.nestedContainer(keyedBy: Self.ElementKeys.self).nestedUnkeyedContainer(forKey: .dataPoints)
            while !pointsContainer.isAtEnd {
                let container = try pointsContainer.nestedContainer(keyedBy: Self.ElementKeys.DataPointKeys.self)
                let timestamp = try container.decode(Int.self, forKey: .date)
                do {
                    let date = Date(timeIntervalSince1970: Double(timestamp / 1000))
                    let open = try decodePoint(container, .open)
                    let close = try decodePoint(container, .close)
                    let highest = try decodePoint(container, .highest)
                    let lowest = try decodePoint(container, .lowest)
                    let volume = try container.decodeIfPresent(UInt.self, forKey: .volume)
                    prices.append(.init(date: date, open: open, close: close, lowest: lowest, highest: highest, volume: volume))
                } catch {
                    print("\(API.Error.printableDomain) Ignoring invalid price data point at timestamp \(timestamp)")
                }
            }
        }
        
        return prices
    }
    
    private enum ElementKeys: String, CodingKey {
        case from = "startTimestamp"
        case to = "endTimestamp"
        case tickCount = "tickCount"
        case dataPoints = "dataPoints"
        
        enum DataPointKeys: String, CodingKey {
            case date = "timestamp"
            case open = "openPrice"
            case close = "closePrice"
            case highest = "highPrice"
            case lowest = "lowPrice"
            case volume = "lastTradedVolume"
            
            enum PriceKeys: String, CodingKey {
                case ask, bid
            }
        }
    }
}

// MARK: - Helpers

extension CodingUserInfoKey {
    /// Key for JSON decoders under which a scaling factor for price values will be stored.
    fileprivate static var scalingFactor: CodingUserInfoKey { CodingUserInfoKey(rawValue: "IG_APIScrappedScaling")! }
}

extension IG.API.Price.Resolution {
    /// The components identifying the receiving resolution.
    fileprivate var components: (number: Int, identifier: String) {
        switch self {
        case .second:   return (1, "SECOND")
        case .minute:   return (1, "MINUTE")
        case .minute2:  return (2, "MINUTE")
        case .minute3:  return (3, "MINUTE")
        case .minute5:  return (5, "MINUTE")
        case .minute10: return (10, "MINUTE")
        case .minute15: return (15, "MINUTE")
        case .minute30: return (30, "MINUTE")
        case .hour:     return (1, "HOUR")
        case .hour2:    return (2, "HOUR")
        case .hour3:    return (3, "HOUR")
        case .hour4:    return (4, "HOUR")
        case .day:      return (1, "DAY")
        case .week:     return (1, "WEEK")
        case .month:    return (1, "MONTH")
        }
    }
    
    /// The number of data points needed for a minute worth.
    fileprivate func numDataPoints(minutes: Int) -> Int {
        switch self {
        case .second:   return minutes * 60
        case .minute:   return minutes
        case .minute2:  return (minutes / 2) + 1
        case .minute3:  return (minutes / 3) + 1
        case .minute5:  return (minutes / 5) + 1
        case .minute10: return (minutes / 10) + 1
        case .minute15: return (minutes / 15) + 1
        case .minute30: return (minutes / 30) + 1
        case .hour:     return (minutes / 60) + 1
        case .hour2:    return (minutes / (60 * 2)) + 1
        case .hour3:    return (minutes / (60 * 3)) + 1
        case .hour4:    return (minutes / (60 * 4)) + 1
        case .day:      return (minutes / (60 * 24)) + 1
        case .week:     return (minutes / (60 * 24 * 7)) + 1
        case .month:    return (minutes / (60 * 24 * 30)) + 1
        }
    }
}
