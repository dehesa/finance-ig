#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#elseif os(tvOS)
import Lightstreamer_tvOS_Client
#else
#error("OS currently not supported")
#endif
import Foundation
import Decimals

extension Streamer.Chart {
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
    }
}

extension Streamer.Chart.Aggregated.Candle {
    /// The representation of a price point.
    public struct Point {
        /// The bid price.
        public let bid: Decimal64?
        /// The ask/offer price.
        public let ask: Decimal64?
    }
}

extension Streamer.Chart.Aggregated {
    /// Dayly statistics.
    public struct Day {
        /// The lowest price of the day.
        public let lowest: Decimal64?
        /// The mid price of the day.
        public let mid: Decimal64?
        /// The highest price of the day
        public let highest: Decimal64?
        /// Net change from open price to current.
        public let changeNet: Decimal64?
        /// Daily percentage change.
        public let changePercentage: Decimal64?
    }
}

// MARK: -

fileprivate typealias F = Streamer.Chart.Aggregated.Field

internal extension Streamer.Chart.Aggregated {
    /// - throws: `IG.Error` exclusively.
    init(epic: IG.Market.Epic, interval: Self.Interval, update: LSItemUpdate, fields: Set<Field>) throws {
        self.epic = epic
        self.interval = interval
        self.candle = try Candle(update: update, fields: fields)
        self.day = try Day(update: update, fields: fields)
    }
}

fileprivate extension Streamer.Chart.Aggregated.Candle {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate, fields: Set<Streamer.Chart.Aggregated.Field>) throws {
        self.date = fields.contains(F.date) ? try update.decodeIfPresent(Date.self, forKey: F.date) : nil
        self.numTicks = fields.contains(F.numTicks) ? try update.decodeIfPresent(Int.self, forKey: F.numTicks) : nil
        self.isFinished = fields.contains(F.isFinished) ? try update.decodeIfPresent(Bool.self, forKey: F.isFinished) : nil
        
        let openBid = fields.contains(F.openBid) ? try update.decodeIfPresent(Decimal64.self, forKey: F.openBid) : nil
        let openAsk = fields.contains(F.openAsk) ? try update.decodeIfPresent(Decimal64.self, forKey: F.openAsk) : nil
        self.open = .init(bid: openBid, ask: openAsk)
        
        let closeBid = fields.contains(F.closeBid) ? try update.decodeIfPresent(Decimal64.self, forKey: F.closeBid) : nil
        let closeAsk = fields.contains(F.closeAsk) ? try update.decodeIfPresent(Decimal64.self, forKey: F.closeAsk) : nil
        self.close = .init(bid: closeBid, ask: closeAsk)
        
        let lowestBid = fields.contains(F.lowestBid) ? try update.decodeIfPresent(Decimal64.self, forKey: F.lowestBid) : nil
        let lowestAsk = fields.contains(F.lowestAsk) ? try update.decodeIfPresent(Decimal64.self, forKey: F.lowestAsk) : nil
        self.lowest = .init(bid: lowestBid, ask: lowestAsk)
        
        let highestBid = fields.contains(F.highestBid) ? try update.decodeIfPresent(Decimal64.self, forKey: F.highestBid) : nil
        let highestAsk = fields.contains(F.highestAsk) ? try update.decodeIfPresent(Decimal64.self, forKey: F.highestAsk) : nil
        self.highest = .init(bid: highestBid, ask: highestAsk)
    }
}

fileprivate extension Streamer.Chart.Aggregated.Day {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate, fields: Set<Streamer.Chart.Aggregated.Field>) throws {
        self.lowest = fields.contains(F.dayLowest) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayLowest) : nil
        self.mid = fields.contains(F.dayMid) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayMid) : nil
        self.highest = fields.contains(F.dayHighest) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayHighest) : nil
        self.changeNet = fields.contains(F.dayChangeNet) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangeNet) : nil
        self.changePercentage = fields.contains(F.dayChangePercentage) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangePercentage) : nil
    }
}
