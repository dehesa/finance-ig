#if os(macOS) && arch(x86_64)
import Lightstreamer_macOS_Client
#elseif os(macOS)

#elseif os(iOS)
import Lightstreamer_iOS_Client
#elseif os(tvOS)
import Lightstreamer_tvOS_Client
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

#if (os(macOS) && arch(x86_64)) || os(iOS) || os(tvOS)

fileprivate typealias F = Streamer.Chart.Tick.Field

internal extension Streamer.Chart.Tick {
    /// - throws: `IG.Error` exclusively.
    init(epic: IG.Market.Epic, item: String, update: LSItemUpdate, fields: Set<Field>) throws {
        self.epic = epic
        self.date = fields.contains(F.date) ? try update.decodeIfPresent(Date.self, forKey: F.date) : nil
        self.bid = fields.contains(F.bid) ? try update.decodeIfPresent(Decimal64.self, forKey: F.bid) : nil
        self.ask = fields.contains(F.ask) ? try update.decodeIfPresent(Decimal64.self, forKey: F.ask) : nil
        self.volume = fields.contains(F.volume) ? try update.decodeIfPresent(Decimal64.self, forKey: F.volume) : nil
        self.day = try .init(update: update, fields: fields)
    }
}

fileprivate extension Streamer.Chart.Tick.Day {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate, fields: Set<Streamer.Chart.Tick.Field>) throws {
        self.lowest = fields.contains(F.dayLowest) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayLowest) : nil
        self.mid = fields.contains(F.dayMid) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayMid) : nil
        self.highest = fields.contains(F.dayHighest) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayHighest) : nil
        self.changeNet = fields.contains(F.dayChangeNet) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangeNet) : nil
        self.changePercentage = fields.contains(F.dayChangePercentage) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangePercentage) : nil
    }
}

#else

internal extension Streamer.Chart.Tick {
    /// - throws: `IG.Error` exclusively.
    init(epic: IG.Market.Epic, item: String, update: Any, fields: Set<Field>) throws {
        fatalError()
    }
}

#endif
