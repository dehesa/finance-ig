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
    init(epic: IG.Market.Epic, interval: Self.Interval, update: Streamer.Packet) throws {
        self.epic = epic
        self.interval = interval
        self.candle = try .init(update: update)
        self.day = try .init(update: update)
    }
}

fileprivate extension Streamer.Chart.Aggregated.Candle {
    /// - throws: `IG.Error` exclusively.
    init(update: Streamer.Packet) throws {
        self.date = try update.decodeIfPresent(Date.self, forKey: F.date)
        self.numTicks = try update.decodeIfPresent(Int.self, forKey: F.numTicks)
        self.isFinished = try update.decodeIfPresent(Bool.self, forKey: F.isFinished)
        
        let openBid = try update.decodeIfPresent(Decimal64.self, forKey: F.openBid)
        let openAsk = try update.decodeIfPresent(Decimal64.self, forKey: F.openAsk)
        self.open = .init(bid: openBid, ask: openAsk)
        
        let closeBid = try update.decodeIfPresent(Decimal64.self, forKey: F.closeBid)
        let closeAsk = try update.decodeIfPresent(Decimal64.self, forKey: F.closeAsk)
        self.close = .init(bid: closeBid, ask: closeAsk)
        
        let lowestBid = try update.decodeIfPresent(Decimal64.self, forKey: F.lowestBid)
        let lowestAsk = try update.decodeIfPresent(Decimal64.self, forKey: F.lowestAsk)
        self.lowest = .init(bid: lowestBid, ask: lowestAsk)
        
        let highestBid = try update.decodeIfPresent(Decimal64.self, forKey: F.highestBid)
        let highestAsk = try update.decodeIfPresent(Decimal64.self, forKey: F.highestAsk)
        self.highest = .init(bid: highestBid, ask: highestAsk)
    }
}

fileprivate extension Streamer.Chart.Aggregated.Day {
    /// - throws: `IG.Error` exclusively.
    init(update: Streamer.Packet) throws {
        self.lowest = try update.decodeIfPresent(Decimal64.self, forKey: F.dayLowest)
        self.mid = try update.decodeIfPresent(Decimal64.self, forKey: F.dayMid)
        self.highest = try update.decodeIfPresent(Decimal64.self, forKey: F.dayHighest)
        self.changeNet = try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangeNet)
        self.changePercentage = try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangePercentage)
    }
}
