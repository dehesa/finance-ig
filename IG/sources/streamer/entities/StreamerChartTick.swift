#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#else
#error("OS currently not supported")
#endif
import Foundation
import Decimals

extension Streamer {
    /// Namespace for all Streamer chart functionality.
    public enum Chart {}
}

extension Streamer.Chart {
    /// Chart data aggregated by a given time interval.
    public struct Tick {
        /// The market epic identifier.
        public let epic: IG.Market.Epic
        /// The date of the information.
        public let date: Date?
        /// The tick bid price.
        public let bid: Decimal64?
        /// The tick ask/offer price.
        public let ask: Decimal64?
        /// Last traded volume.
        public let volume: Decimal64?
        /// Aggregate data for the current day.
        public let day: Self.Day
    }
}

extension Streamer.Chart.Tick {
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

fileprivate typealias F = Streamer.Chart.Tick.Field

internal extension Streamer.Chart.Tick {
    /// - throws: `IG.Error` exclusively.
    init(epic: IG.Market.Epic, item: String, update: LSItemUpdate) throws {
        self.epic = epic
        self.date = try update.decodeIfPresent(Date.self, forKey: F.date)
        self.bid = try update.decodeIfPresent(Decimal64.self, forKey: F.bid)
        self.ask = try update.decodeIfPresent(Decimal64.self, forKey: F.ask)
        self.volume = try update.decodeIfPresent(Decimal64.self, forKey: F.volume)
        self.day = try .init(update: update)
    }
}

fileprivate extension Streamer.Chart.Tick.Day {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate) throws {
        self.lowest = try update.decodeIfPresent(Decimal64.self, forKey: F.dayLowest)
        self.mid = try update.decodeIfPresent(Decimal64.self, forKey: F.dayMid)
        self.highest = try update.decodeIfPresent(Decimal64.self, forKey: F.dayHighest)
        self.changeNet = try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangeNet)
        self.changePercentage = try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangePercentage)
    }
}
