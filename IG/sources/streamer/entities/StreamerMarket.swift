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
    public enum Status {
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
    init(epic: IG.Market.Epic, update: Streamer.Packet, timeFormatter: DateFormatter) throws {
        self.epic = epic
        
        if let status = update[F.status.rawValue]?.value {
            switch status {
            case "TRADEABLE": self.status = .tradeable
            case "CLOSED": self.status = .closed
            case "EDIT": self.status = .editsOnly
            case "AUCTION": self.status = .onAuction
            case "AUCTION_NO_EDIT": self.status = .onAuctionNoEdits
            case "OFFLINE": self.status = .offline
            case "SUSPENDED": self.status = .suspended
            case let value: throw IG.Error(.streamer(.invalidResponse), "Invalid status field", help: "Contact the repo maintainer and copy this error message.", info: ["Field": F.status, "Value": value])
            }
        } else { self.status = nil }
        
        self.date = try update.decodeIfPresent(Date.self, with: timeFormatter, forKey: F.date)
        self.isDelayed = try update.decodeIfPresent(Bool.self, forKey: F.isDelayed)
        self.bid = try update.decodeIfPresent(Decimal64.self, forKey: F.bid)
        self.ask = try update.decodeIfPresent(Decimal64.self, forKey: F.ask)
        self.day = try .init(update: update)
    }
}

fileprivate extension Streamer.Market.Day {
    /// - throws: `IG.Error` exclusively.
    init(update: Streamer.Packet) throws {
        self.lowest = try update.decodeIfPresent(Decimal64.self, forKey: F.dayLowest)
        self.mid = try update.decodeIfPresent(Decimal64.self, forKey: F.dayMid)
        self.highest = try update.decodeIfPresent(Decimal64.self, forKey: F.dayHighest)
        self.changeNet = try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangeNet)
        self.changePercentage = try update.decodeIfPresent(Decimal64.self, forKey: F.dayChangePercentage)
    }
}
