import Foundation
import Decimals

extension API {
    /// Market snapshot retrieved from a scrapped endpoint.
    public struct PriceSnapshot {
        /// The epic identifying the market.
        public let epic: IG.Market.Epic
        /// The market's name.
        public let name: String
        /// The locale used to express numbers.
        public let locale: Locale
        /// Number of decimal positions for pip representation.
        public let decimalPlaces: Decimal64
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Decimal64
        /// Boolean indicating whether the price data point values has been scaled.
        ///
        /// The prices displayed by this structure are "real" and don't require any further processing; however, this boolean indicates whether other scrapped endpoints returned scaled values.
        public let isScaled: Bool
        /// Boolean indicating whether the snapshot prices are delayed.
        public let delay: Int
        /// The time offset from UTC.
        public let offsetToUTC: TimeInterval
        /// The price data points available throught the batch endpoint.
        ///
        /// The available prices always end at the previous hour ends. For example, if at API endpoint call time  is 10:20 UTC, the last available price will be 09:59 UTC.
        public let availableBatchPrices: DateInterval
        /// The prices brought with the snapshot (already ordered by the server).
        public let prices: [API.Price]
    }
}

// MARK: -

extension API.PriceSnapshot: Decodable {
    public init(from decoder: Decoder) throws {
        let topContainer = try decoder.container(keyedBy: _Keys.self)
        
        let instrumentContainer = try topContainer.nestedContainer(keyedBy: _Keys._InstrumentKeys.self, forKey: .instrument)
        self.epic = try instrumentContainer.decode(IG.Market.Epic.self, forKey: .epic)
        self.name = try instrumentContainer.decode(String.self, forKey: .name)
        self.locale = Locale(identifier: try instrumentContainer.decode(String.self, forKey: .locale))
        self.scalingFactor = try Decimal64(try instrumentContainer.decode(String.self, forKey: .scalingFactor)) ?> DecodingError.dataCorruptedError(forKey: .scalingFactor, in: instrumentContainer, debugDescription: "The 'scaling factor' value cannot be transformed into a numeric value")
        self.decimalPlaces = try Decimal64(try instrumentContainer.decode(String.self, forKey: .decimalPlaces)) ?> DecodingError.dataCorruptedError(forKey: .decimalPlaces, in: instrumentContainer, debugDescription: "The 'decimal places' value cannot be transformed into a numeric value")
        self.isScaled = try instrumentContainer.decode(Bool.self, forKey: .isScaled)
        self.delay = try instrumentContainer.decode(Int.self, forKey: .delay)
        
        let intervalContainer = try topContainer.nestedContainer(keyedBy: _Keys._IntervalKeys.self, forKey: .intervals)
        let start = try intervalContainer.decode(Int.self, forKey: .startTimestamp)
        let end = try intervalContainer.decode(Int.self, forKey: .endTimestamp)
        self.availableBatchPrices = DateInterval(start: Date(timeIntervalSince1970: Double(start / 1000)),
                                                 end: Date(timeIntervalSince1970: Double(end   / 1000)) )
        self.offsetToUTC = try intervalContainer.decode(TimeInterval.self, forKey: .offsetToUTC)
        
        let storageContainer = try topContainer.nestedContainer(keyedBy: _Keys._StorageKeys.self, forKey: .storage)
        //let offset: TimeInterval = (try storageContainer.decode(Bool.self, forKey: .isConsolidated)) ? try intervalContainer.decode(TimeInterval.self, forKey: .consolidationTimezoneOffset) : 0
        
        let scalingFactor = (self.isScaled) ? self.scalingFactor : Decimal64(1)
        let elementsContainer = try storageContainer.nestedUnkeyedContainer(forKey: .elements)
        self.prices = try Self._decode(scrappedDataPoints: elementsContainer, scalingFactor: scalingFactor)
    }
    
    private enum _Keys: String, CodingKey {
        case instrument = "instrumentInfoDto"
        case intervals = "intervalsDto"
        case storage = "intervalsDataPointsDto"
        
        enum _InstrumentKeys: String, CodingKey {
            case epic, name, locale = "nameLocale"
            case scalingFactor, decimalPlaces
            case delay, isScaled = "scaled"
        }
        
        enum _IntervalKeys: String, CodingKey {
            case startTimestamp, endTimestamp
            case offsetToUTC
            case consolidationTimezoneOffset
        }
        
        enum _StorageKeys: String, CodingKey {
            case elements = "intervalsDataPoints"
        }
    }
}

internal extension API.Market {
    /// A batch of data prices.
    struct _ScrappedBatch: Decodable {
        /// ???
        let isConsolidated: Bool
        /// The identifier for the given transaction.
        let transactionIdentifier: String
        /// All the data prices.
        let prices: [API.Price]
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self._Keys.self)
            self.isConsolidated = try container.decode(Bool.self, forKey: .isConsolidated)
            self.transactionIdentifier = try container.decode(String.self, forKey: .transactionIdentifier)
            
            let unkeyedContainer = try container.nestedUnkeyedContainer(forKey: .prices)
            let scalingFactor = try (decoder.userInfo[._scalingFactor] as? Decimal64) ?> DecodingError.valueNotFound(Decimal64.self, .init(codingPath: container.codingPath, debugDescription: "The userInfo value under key '\(CodingUserInfoKey._scalingFactor)' wasn't found or it was invalid"))
            self.prices = try API.PriceSnapshot._decode(scrappedDataPoints: unkeyedContainer, scalingFactor: scalingFactor)
        }
        
        private enum _Keys: String, CodingKey {
            case isConsolidated = "consolidated"
            case transactionIdentifier = "transactionId"
            case prices = "intervalsDataPoints"
        }
    }
}

fileprivate extension API.PriceSnapshot {
    /// Extracted functionality decoding all price data points under a given unkeyed decoding container.
    static func _decode(scrappedDataPoints: UnkeyedDecodingContainer, scalingFactor: Decimal64) throws -> [API.Price] {
        var prices: [API.Price] = []
        
        let decodePoint: (KeyedDecodingContainer<_ElementKeys.DataPointKeys>, _ElementKeys.DataPointKeys) throws -> API.Price.Point = {
            let pointContainer = try $0.nestedContainer(keyedBy: _ElementKeys.DataPointKeys.PriceKeys.self, forKey: $1)
            let bid = try pointContainer.decode(Decimal64.self, forKey: .bid) / scalingFactor
            let ask = try pointContainer.decode(Decimal64.self, forKey: .ask) / scalingFactor
            return .init(bid: bid, ask: ask, lastTraded: nil)
        }
        
        var elementsContainer = scrappedDataPoints
        while !elementsContainer.isAtEnd {
            var pointsContainer = try elementsContainer.nestedContainer(keyedBy: _ElementKeys.self).nestedUnkeyedContainer(forKey: .dataPoints)
            while !pointsContainer.isAtEnd {
                let container = try pointsContainer.nestedContainer(keyedBy: _ElementKeys.DataPointKeys.self)
                let timestamp = try container.decode(Int.self, forKey: .date)
                let date = Date(timeIntervalSince1970: Double(timestamp / 1000))
                do {
                    let open = try decodePoint(container, .open)
                    let close = try decodePoint(container, .close)
                    let highest = try decodePoint(container, .highest)
                    let lowest = try decodePoint(container, .lowest)
                    let volume = try container.decodeIfPresent(UInt.self, forKey: .volume)
                    prices.append(.init(date: date, open: open, close: close, lowest: lowest, highest: highest, volume: volume))
                } catch /*let error*/ {
                    //                    #if DEBUG
                    //                    print("Ignoring invalid price data point at timestamp \(date)\t\n\(error)")
                    //                    #endif
                    continue
                }
            }
        }
        
        return prices
    }
    
    private enum _ElementKeys: String, CodingKey {
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
