import ReactiveSwift
import Foundation

extension Streamer.Request.Markets {
    
    // MARK: CHART:EPIC:SCALE
    
    /// Subscribes to a given market and returns aggreagated chart data for a specific time interval.
    ///
    /// For example, if subscribed to EUR/USD on the 5-minute interval; the data received will be the one of the last 5-minute candle and some statistics of the day.
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
        
        /// Candle bid open price.
        case openBid = "BID_OPEN"
        /// Candle offer open price.
        case openAsk = "OFR_OPEN"
        /// Candle bid close price.
        case closeBid = "BID_CLOSE"
        /// Candle offer close price.
        case closeAsk = "OFR_CLOSE"
        /// Candle bid low price.
        case lowestBid = "BID_LOW"
        /// Candle offer low price.
        case lowestAsk = "OFR_LOW"
        /// Candle bid high price.
        case highestBid = "BID_HIGH"
        /// Candle offer high price.
        case highestAsk = "OFR_HIGH"
        /// Whether the candle has ended (1 ends, 0 continues).
        case isFinished = "CONS_END"
        /// Number of ticks in candle.
        case numTicks = "CONS_TICK_COUNT"
        /// Last traded volume.
        case lastTradedVolume = "LTV"
        // /// Candle open price (Last Traded Price)
        // case lastTradedPriceOpen = "LTP_OPEN"
        // /// Candle low price (Last Traded Price)
        // case lastTradedPriceLow = "LTP_LOW"
        // /// Candle high price (Last Traded Price)
        // case lastTradedPriceHigh = "LTP_HIGH"
        // /// Candle close price (Last Traded Price)
        // case lastTradedPriceClose = "LTP_CLOSE"
        // /// Incremental trading volume.
        // case incrementalTradingVolume = "TTV"
        /// Daily low price.
        case dayLowest = "DAY_LOW"
        /// Mid open price for the day.
        case dayMid = "DAY_OPEN_MID"
        /// Daily high price.
        case dayHighest = "DAY_HIGH"
        /// Change from open price to current.
        case dayChangeNet = "DAY_NET_CHG_MID"
        /// Daily percentage change.
        case dayChangePercentage = "DAY_PERC_CHG_MID"
    }
}

extension Set where Element == Streamer.Chart.Aggregated.Field {
    /// Returns a set with all the candle related fields.
    public static var candle: Self {
        return Self.init([.date, .openBid, .openAsk, .closeBid, .closeAsk,
                          .lowestBid, .lowestAsk, .highestBid, .highestAsk,
                          .isFinished, .numTicks, .lastTradedVolume])
    }
    /// Returns a set with all the dayly related fields.
    public static var day: Self {
        return Self.init([.dayLowest, .dayMid, .dayHighest, .dayChangeNet, .dayChangePercentage])
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
        /// The candle for the ongoing time interval.
        public let candle: Self.Candle
        /// Aggregate data for the current day.
        public let day: Self.Day
        
        internal init(epic: Epic, interval: Self.Interval, item: String, update: [String:String]) throws {
            typealias F = Self.Field
            typealias U = Streamer.Formatter.Update
            
            self.epic = epic
            self.interval = interval
            
            do {
                self.candle = try .init(update: update)
                self.day = try .init(update: update)
            } catch let error as Streamer.Formatter.Update.Error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An error was encountered when parsing the value \"\(error.value)\" from a \"String\" to a \"\(error.type)\".")
            } catch let error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An unknown error was encountered when parsing the updated payload.\nError: \(error)")
            }
        }
    }
}

extension Streamer.Chart.Aggregated {
    /// Buy/Sell prices at a point in time.
    public struct Candle {
        /// The date of the information.
        public let date: Date?
        /// Number of ticks in the candle.
        public let numTicks: Int?
        /// Boolean indicating whether no further values will be added to this candle.
        public let isFinished: Bool?
        /// The open bid/ask price for the receiving candle.
        public let open: Self.Point
        /// The close bid/ask price for the receiving candle.
        public let close: Self.Point
        /// The lowest bid/ask price for the receiving candle.
        public let lowest: Self.Point
        /// The highest bid/ask price for the receiving candle.
        public let highest: Self.Point

        fileprivate init(update: [String:String]) throws {
            typealias F = Streamer.Chart.Aggregated.Field
            typealias U = Streamer.Formatter.Update
            
            self.date = try update[F.date.rawValue].map(U.toEpochDate)
            self.numTicks = try update[F.numTicks.rawValue].map(U.toInt)
            self.isFinished = try update[F.isFinished.rawValue].map(U.toBoolean)
            
            let openBid = try update[F.openBid.rawValue].map(U.toDecimal)
            let openAsk = try update[F.openAsk.rawValue].map(U.toDecimal)
            self.open = .init(bid: openBid, ask: openAsk)
            
            let closeBid = try update[F.closeBid.rawValue].map(U.toDecimal)
            let closeAsk = try update[F.closeAsk.rawValue].map(U.toDecimal)
            self.close = .init(bid: closeBid, ask: closeAsk)
            
            let lowestBid = try update[F.lowestBid.rawValue].map(U.toDecimal)
            let lowestAsk = try update[F.lowestAsk.rawValue].map(U.toDecimal)
            self.lowest = .init(bid: lowestBid, ask: lowestAsk)
            
            let highestBid = try update[F.highestBid.rawValue].map(U.toDecimal)
            let highestAsk = try update[F.highestAsk.rawValue].map(U.toDecimal)
            self.highest = .init(bid: highestBid, ask: highestAsk)
        }
        
        /// The representation of a price point.
        public struct Point {
            /// The bid price.
            public let bid: Decimal?
            /// The ask/offer price.
            public let ask: Decimal?
            
            /// Hidden designated initializer.
            fileprivate init(bid: Decimal?, ask: Decimal?) {
                self.bid = bid
                self.ask = ask
            }
        }
    }

    /// Trading volume related information.
    public struct Day {
        /// The lowest price of the day.
        public let lowest: Decimal?
        /// The mid price of the day.
        public let mid: Decimal?
        /// The highest price of the day
        public let highest: Decimal?
        /// Net change from open price to current.
        public let changeNet: Decimal?
        /// Daily percentage change.
        public let changePercentage: Decimal?

        fileprivate init(update: [String:String]) throws {
            typealias F = Streamer.Chart.Aggregated.Field
            typealias U = Streamer.Formatter.Update

            self.lowest = try update[F.dayLowest.rawValue].map(U.toDecimal)
            self.mid = try update[F.dayMid.rawValue].map(U.toDecimal)
            self.highest = try update[F.dayHighest.rawValue].map(U.toDecimal)
            self.changeNet = try update[F.dayChangeNet.rawValue].map(U.toDecimal)
            self.changePercentage = try update[F.dayChangePercentage.rawValue].map(U.toDecimal)
        }
    }
}
