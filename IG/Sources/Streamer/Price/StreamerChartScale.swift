import Combine
import Foundation

extension IG.Streamer.Request {
    /// Contains all functionality related to Streamer charts.
    public struct Price {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        internal unowned let streamer: IG.Streamer
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: IG.Streamer) { self.streamer = streamer }
    }
}

extension IG.Streamer.Request.Price {
    
    // MARK: CHART:EPIC:SCALE
    
    /// Subscribes to a given market and returns aggreagated chart data for a specific time interval.
    ///
    /// For example, if subscribed to EUR/USD on the 5-minute interval; the data received will be the one of the last 5-minute candle and some statistics of the day.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter interval: The aggregation interval for the candle.
    /// - parameter fields: The chart properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market. explicitly call `connect()`.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(epic: IG.Market.Epic, interval: IG.Streamer.Chart.Aggregated.Interval, fields: Set<IG.Streamer.Chart.Aggregated.Field>, snapshot: Bool = true) -> IG.Streamer.Publishers.Continuous<IG.Streamer.Chart.Aggregated> {
        let item = "CHART:\(epic.rawValue):\(interval.rawValue)"
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(on: self.streamer.queue, mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .tryMap { (update) in
                do {
                    return try .init(epic: epic, interval: interval, item: item, update: update)
                } catch var error as IG.Streamer.Error {
                    if case .none = error.item { error.item = item }
                    if case .none = error.fields { error.fields = properties }
                    throw error
                } catch let underlyingError {
                    throw IG.Streamer.Error.invalidResponse(.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: .reviewError)
                }
            }.mapError(IG.Streamer.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.Streamer.Chart.Aggregated {
    /// The time interval used for aggregation.
    public enum Interval: String {
        case second = "SECOND"
        case minute = "1MINUTE"
        case minute5 = "5MINUTE"
        case hour = "HOUR"
        
        var seconds: TimeInterval {
            switch self {
            case .second: return 1
            case .minute: return 60
            case .minute5: return 300
            case .hour: return 3600
            }
        }
    }
}

extension IG.Streamer.Chart.Aggregated {
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
        case volume = "LTV"
        // /// Incremental trading volume.
        // case incrementalVolume = "TTV"
        // /// Candle open price (Last Traded Price)
        // case lastTradedPriceOpen = "LTP_OPEN"
        // /// Candle low price (Last Traded Price)
        // case lastTradedPriceLow = "LTP_LOW"
        // /// Candle high price (Last Traded Price)
        // case lastTradedPriceHigh = "LTP_HIGH"
        // /// Candle close price (Last Traded Price)
        // case lastTradedPriceClose = "LTP_CLOSE"
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

extension Set where Element == IG.Streamer.Chart.Aggregated.Field {
    /// Returns a set with all the candle related fields.
    public static var candle: Self {
        return Self.init([.date, .openBid, .openAsk, .closeBid, .closeAsk,
                          .lowestBid, .lowestAsk, .highestBid, .highestAsk,
                          .isFinished, .numTicks, .volume])
    }
    
    /// Returns a set with all the dayly related fields.
    public static var day: Self {
        return Self.init([.dayLowest, .dayMid, .dayHighest, .dayChangeNet, .dayChangePercentage])
    }
    
    /// Returns all queryable fields.
    public static var all: Self {
        return .init(Element.allCases)
    }
}

// MARK: Response Entities

extension IG.Streamer {
    /// Namespace for all Streamer chart functionality.
    public enum Chart {}
}

extension IG.Streamer.Chart {
    /// Chart data aggregated by a given time interval.
    public struct Aggregated {
        /// The market epic identifier.
        public let epic: IG.Market.Epic
        /// The aggregation interval chosen on subscription.
        public let interval: Self.Interval
        /// The candle for the ongoing time interval.
        public let candle: Self.Candle
        /// Aggregate data for the current day.
        public let day: Self.Day
        
        internal init(epic: IG.Market.Epic, interval: Self.Interval, item: String, update: IG.Streamer.Packet) throws {
            typealias F = Self.Field
            typealias U = IG.Streamer.Formatter.Update
            typealias E = IG.Streamer.Error
            
            self.epic = epic
            self.interval = interval
            
            do {
                self.candle = try .init(update: update)
                self.day = try .init(update: update)
            } catch let error as U.Error {
                throw E.invalidResponse(E.Message.parsing(update: error), item: item, update: update, underlying: error, suggestion: E.Suggestion.fileBug)
            } catch let underlyingError {
                throw E.invalidResponse(E.Message.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: E.Suggestion.reviewError)
            }
        }
    }
}

extension IG.Streamer.Chart.Aggregated {
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

        fileprivate init(update: IG.Streamer.Packet) throws {
            typealias F = IG.Streamer.Chart.Aggregated.Field
            typealias U = IG.Streamer.Formatter.Update
            
            self.date = try update[F.date.rawValue]?.value.map(U.toEpochDate)
            self.numTicks = try update[F.numTicks.rawValue]?.value.map(U.toInt)
            self.isFinished = try update[F.isFinished.rawValue]?.value.map(U.toBoolean)
            
            let openBid = try update[F.openBid.rawValue]?.value.map(U.toDecimal)
            let openAsk = try update[F.openAsk.rawValue]?.value.map(U.toDecimal)
            self.open = .init(bid: openBid, ask: openAsk)
            
            let closeBid = try update[F.closeBid.rawValue]?.value.map(U.toDecimal)
            let closeAsk = try update[F.closeAsk.rawValue]?.value.map(U.toDecimal)
            self.close = .init(bid: closeBid, ask: closeAsk)
            
            let lowestBid = try update[F.lowestBid.rawValue]?.value.map(U.toDecimal)
            let lowestAsk = try update[F.lowestAsk.rawValue]?.value.map(U.toDecimal)
            self.lowest = .init(bid: lowestBid, ask: lowestAsk)
            
            let highestBid = try update[F.highestBid.rawValue]?.value.map(U.toDecimal)
            let highestAsk = try update[F.highestAsk.rawValue]?.value.map(U.toDecimal)
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

    /// Dayly statistics.
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

        fileprivate init(update: IG.Streamer.Packet) throws {
            typealias F = IG.Streamer.Chart.Aggregated.Field
            typealias U = IG.Streamer.Formatter.Update

            self.lowest = try update[F.dayLowest.rawValue]?.value.map(U.toDecimal)
            self.mid = try update[F.dayMid.rawValue]?.value.map(U.toDecimal)
            self.highest = try update[F.dayHighest.rawValue]?.value.map(U.toDecimal)
            self.changeNet = try update[F.dayChangeNet.rawValue]?.value.map(U.toDecimal)
            self.changePercentage = try update[F.dayChangePercentage.rawValue]?.value.map(U.toDecimal)
        }
    }
}

extension IG.Streamer.Chart.Aggregated: IG.DebugDescriptable {
    internal static var printableDomain: String { "\(IG.Streamer.printableDomain).\(IG.Streamer.Chart.self).\(Self.self)" }
    
    public var debugDescription: String {
        let represent: (Self.Candle.Point)->String = {
            switch ($0.bid, $0.ask) {
            case (nil, nil): return IG.DebugDescription.Symbol.nil
            case (let bid?, let ask?): return "\(ask) ask, \(bid) bid"
            case (let bid?, nil): return "\(IG.DebugDescription.Symbol.nil) ask, \(bid) bid"
            case (nil, let ask?): return "\(ask) ask, \(IG.DebugDescription.Symbol.nil) bid"
            }
        }
        
        var result = IG.DebugDescription("\(Self.printableDomain) \(self.interval) (\(self.epic))")
        result.append("candle", self.candle) {
            $0.append("date", $1.date, formatter: IG.Streamer.Formatter.time)
            $0.append("ticks", $1.numTicks)
            $0.append("is finished", $1.isFinished)
            $0.append("open", represent($1.open))
            $0.append("close", represent($1.close))
            $0.append("lowest", represent($1.lowest))
            $0.append("highest", represent($1.highest))
        }
        result.append("day", self.day) {
            $0.append("range (high)", $1.highest)
            $0.append("range (mid)", $1.mid)
            $0.append("range (low)", $1.lowest)
            $0.append("change (net)", $1.changeNet)
            $0.append("change (%)", $1.changePercentage)
        }
        return result.generate()
    }
}
