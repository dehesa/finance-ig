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

extension Streamer {
    /// Displays the latests information from a given market.
    public struct Market {
        /// The market epic identifier.
        public let epic: IG.Market.Epic
        /// The current market status.
        public let status: Self.Status?
        
        /// Publish time of last price update.
        public let date: Date?
        /// Boolean indicating whether prices are delayed.
        public let isDelayed: Bool?
        
        /// The bid price.
        public let bid: Decimal64?
        /// The offer price.
        public let ask: Decimal64?
        
        /// Aggregate data for the current day.
        public let day: Self.Day
    }
}

extension Streamer.Market {
    /// The current status of the market.
    public enum Status: Hashable {
        /// The market is open for trading.
        case tradeable
        /// The market is closed for the moment. Look at the market's opening hours for further information.
        case closed
        case editsOnly
        case onAuction
        case onAuctionNoEdits
        case offline
        /// The market is suspended for trading temporarily.
        case suspended
    }
    
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

fileprivate typealias F = Streamer.Market.Field

internal extension Streamer.Market {
    /// - throws: `IG.Error` exclusively.
    init(epic: IG.Market.Epic, update: LSItemUpdate, timeFormatter: DateFormatter, fields: Set<Field>) throws {
        self.epic = epic
        
        if fields.contains(F.status), let status = update.decodeIfPresent(String.self, forKey: F.status) {
            switch status {
            case "TRADEABLE": self.status = .tradeable
            case "CLOSED": self.status = .closed
            case "EDIT": self.status = .editsOnly
            case "AUCTION": self.status = .onAuction
            case "AUCTION_NO_EDIT": self.status = .onAuctionNoEdits
            case "OFFLINE": self.status = .offline
            case "SUSPENDED": self.status = .suspended
            case let value: throw IG.Error._invalid(status: value)
            }
        } else { self.status = nil }
        
        self.date = fields.contains(F.date) ? try update.decodeIfPresent(Date.self, with: timeFormatter, forKey: F.date) : nil
        self.isDelayed = fields.contains(F.isDelayed) ? try update.decodeIfPresent(Bool.self, forKey: F.isDelayed) : nil
        self.bid = fields.contains(F.bid) ? try update.decodeIfPresent(Decimal64.self, forKey: F.bid) : nil
        self.ask = fields.contains(F.ask) ? try update.decodeIfPresent(Decimal64.self, forKey: F.ask) : nil
        self.day = try .init(update: update, fields: fields)
    }
}

fileprivate extension Streamer.Market.Day {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate, fields: Set<Streamer.Market.Field>) throws {
        self.lowest = fields.contains(F.dayLowest) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayLowest) : nil
        self.mid = fields.contains(F.dayMid) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayMid) : nil
        self.highest = fields.contains(F.dayHighest) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayHighest) : nil
        self.changeNet = fields.contains(F.dayChangeNet) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangeNet) : nil
        self.changePercentage = fields.contains(F.dayChangePercentage) ? try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangePercentage) : nil
    }
}

private extension IG.Error {
    /// Error raised when the status field is invalid.
    static func _invalid(status: String) -> Self {
        Self(.streamer(.invalidResponse), "Invalid status field", help: "Contact the repo maintainer and copy this error message.", info: ["Field": F.status, "Value": status])
    }
}
