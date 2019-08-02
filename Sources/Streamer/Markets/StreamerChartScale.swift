import ReactiveSwift
import Foundation

extension Streamer.Request.Markets {
    
    // MARK: CHART:EPIC:SCALE
    
    /// Subscribes to a given market and returns aggreagated chart data.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter interval: The aggregation interval for the candle.
    /// - parameter fields: The chart properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market. explicitly call `connect()`.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(to epic: Epic, aggregation interval: Streamer.Chart.Aggregated.Interval, _ fields: Set<Streamer.Chart.Aggregated.Field>, snapshot: Bool = true) -> SignalProducer<Streamer.Chart.Aggregated,Streamer.Error> {
        let item = "CHART:\(epic.rawValue):\(interval.rawValue)"
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .attemptMap { (update) in
                do {
                    let account = try Streamer.Chart.Aggregated(epic: epic, interval: interval, item: item, update: update)
                    return .success(account)
                } catch let error as Streamer.Error {
                    return .failure(error)
                } catch let error {
                    return .failure(.invalidResponse(item: item, fields: update, message: "An unkwnon error occur will parsing a market chart update.\nError: \(error)"))
                }
            }
    }
}

// MARK: - Supporting Entities

// MARK: Request Entities

extension Streamer.Chart.Aggregated {
    /// The time interval used for aggregation.
    public enum Interval: String {
        case second = "SECOND"
        case minute = "1MINUTE"
        case minutes5 = "5MINUTE"
        case hour = "HOUR"
    }
}

extension Streamer.Chart.Aggregated {
    /// Possible fields to subscribe to when querying market candle data.
    public enum Field: String, CaseIterable {
        /// Update time.
        case date = "UTM"
        /// Whether the candle has ended (1 ends, 0 continues).
        case isFinished = "CONS_END"
        /// Number of ticks in candle.
        case numTicks = "CONS_TICK_COUNT"
        
        /// Candle bid open price.
        case bidOpen = "BID_OPEN"
        /// Candle bid low price.
        case bidLow = "BID_LOW"
        /// Candle bid high price.
        case bidHigh = "BID_HIGH"
        /// Candle bid close price.
        case bidClose = "BID_CLOSE"
        /// Candle offer open price.
        case askOpen = "OFR_OPEN"
        /// Candle offer low price.
        case askLow = "OFR_LOW"
        /// Candle offer high price.
        case askHigh = "OFR_HIGH"
        /// Candle offer close price.
        case askClose = "OFR_CLOSE"
        // /// Candle open price (Last Traded Price)
        // case lastTradedPriceOpen = "LTP_OPEN"
        // /// Candle low price (Last Traded Price)
        // case lastTradedPriceLow = "LTP_LOW"
        // /// Candle high price (Last Traded Price)
        // case lastTradedPriceHigh = "LTP_HIGH"
        // /// Candle close price (Last Traded Price)
        // case lastTradedPriceClose = "LTP_CLOSE"
        /// Last traded volume.
        case lastTradedVolume = "LTV"
        // /// Incremental trading volume.
        // case incrementalTradingVolume = "TTV"
        /// Daily low price.
        case low = "DAY_LOW"
        /// Mid open price for the day.
        case midOpen = "DAY_OPEN_MID"
        /// Daily high price.
        case high = "DAY_HIGH"
        /// Change from open price to current.
        case changeNet = "DAY_NET_CHG_MID"
        /// Daily percentage change.
        case changePercentage = "DAY_PERC_CHG_MID"
    }
}

// MARK: Response Entities

extension Streamer {
    /// Namespace for all Streamer chart functionality.
    public enum Chart {}
}

extension Streamer.Chart {
    /// Chart data aggregated by a given time interval.
    public struct Aggregated {
        /// The market epic identifier.
        public let epic: Epic
        /// The aggregation interval chosen on subscription.
        public let interval: Self.Interval
        
        /// The date of the information.
        public let date: Date?
        /// Boolean indicating whether no further values will be added to this candle.
        public let isFinished: Bool?
        /// Number of ticks in the candle.
        public let numTicks: Int?
        
        /// Price related information (e.g. buy, sell price, etc.)
        public let price: Self.Price
        /// Traded volume information.
        public let volume: Self.Volume
        /// Highest and lowest price of the day.
        public let intraday: Self.Intraday
        
        internal init(epic: Epic, interval: Self.Interval, item: String, update: [String:String]) throws {
            typealias F = Self.Field
            typealias U = Streamer.Formatter.Update
            
            self.epic = epic
            self.interval = interval
            
            do {
                self.date = try update[F.date.rawValue].map(U.toEpochDate)
                self.isFinished = try update[F.isFinished.rawValue].map(U.toBoolean)
                self.numTicks = try update[F.numTicks.rawValue].map(U.toInt)
                self.price = try .init(update: update)
                self.volume = try .init(update: update)
                self.intraday = try .init(update: update)
            } catch let error as Streamer.Formatter.Update.Error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An error was encountered when parsing the value \"\(error.value)\" from a \"String\" to a \"\(error.type)\".")
            } catch let error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An unknown error was encountered when parsing the updated payload.\nError: \(error)")
            }
        }
    }
}

//        internal init(update: StreamerSubscriptionUpdate) throws {
//            self.date = values[.date].flatMap {
//                guard let milliseconds = TimeInterval($0) else { return nil }
//                return Date(timeIntervalSince1970: milliseconds / 1000)
//            }
//            self.isFinished = values[.isFinished].flatMap {
//                guard let number = Int($0) else { return nil }
//                return number != 0
//            }
//            self.numTicks = values[.numTicks].flatMap { Int($0) }
//            self.price = Price(received: values)
//            self.volume = Volume(received: values)
//            self.intraday = Intraday(received: values)
//        }

extension Streamer.Chart.Aggregated {
    /// Buy/Sell prices at a point in time.
    public struct Price {
//        /// Buy price.
//        public let offer: Range
//        /// Sell price.
//        public let bid: Range
        // /// Last traded price.
        // public let lastTraded: Properties

        fileprivate init(update: [String:String]) throws {
//            typealias F = Self.Field
//            typealias U = Streamer.Formatter.Update
//
//            self.offer = Range(received: received, fields: (.offerOpen, .offerClose, .offerLow, .offerHigh))
//            self.bid = Range(received: received, fields: (.bidOpen, .bidClose, .bidLow, .bidHigh))
//            // self.lastTraded = Properties(received: received, fields: (.lastTradedPriceOpen, .lastTradedPriceClose, .lastTradedPriceLow, .lastTradedPriceHigh))
        }
    }

    /// Trading volume related information.
    public struct Volume {
//        /// Last traded volume.
//        public let lastTraded: Double?
//        // /// Incremental trading volume.
//        // public let incremental: Double?

        fileprivate init(update: [String:String]) throws {
//            typealias F = Self.Field
//            typealias U = Streamer.Formatter.Update
//
//            self.lastTraded = received[.lastTradedVolume].flatMap { Double($0) }
//            // self.incremental = received[.incrementalTradingVolume].flatMap { Double($0) }
        }
    }

    /// The price range.
    public struct Intraday {
//        /// Intraday lowest price.
//        public let low: Double?
//        /// Opening mid price.
//        public let midOpen: Double?
//        /// Intraday highest price.
//        public let high: Double?
//        /// Price change net and percentage change on that day.
//        public let change: Change

        fileprivate init(update: [String:String]) throws {
//            typealias F = Self.Field
//            typealias U = Streamer.Formatter.Update
//
//            self.low = received[.low].flatMap { Double($0) }
//            self.midOpen = received[.midOpen].flatMap { Double($0) }
//            self.high = received[.high].flatMap { Double($0) }
//            self.change = Change(received: received)
        }
    }
}

//extension Streamer.Response.Chart.Candle {
//    /// Price candle properties.
//    public struct Range {
//        /// The open price for a given candle.
//        public let open: Double?
//        /// The close price for a given candle.
//        public let close: Double?
//        /// The lowest price reached on a candle.
//        public let low: Double?
//        /// The highest price reached on a candle.
//        public let high: Double?
//
//        fileprivate init(received: [Field:String], fields: (open: Field, close: Field, low: Field, high: Field)) {
//            self.open = received[fields.open].flatMap { Double($0) }
//            self.close = received[fields.close].flatMap { Double($0) }
//            self.low = received[fields.low].flatMap { Double($0) }
//            self.high = received[fields.high].flatMap { Double($0) }
//        }
//    }
//
//    /// The change in price.
//    public struct Change {
//        /// Change from open price to current.
//        public let net: Double?
//        /// Daily percentage change.
//        public let percentage: Double?
//
//        fileprivate init(received: [Field:String]) {
//            self.net = received[.changeNet].flatMap { Double($0) }
//            self.percentage = received[.changePercentage].flatMap { Double($0) }
//        }
//    }
//}
