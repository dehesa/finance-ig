import Combine
import Foundation

extension IG.Streamer.Request {
    /// Contains all functionality related to Streamer markets.
    public struct Markets {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        internal unowned let streamer: IG.Streamer
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: IG.Streamer) {
            self.streamer = streamer
        }
    }
}

extension IG.Streamer.Request.Markets {
    
    // MARK: MARKET:EPIC
    
    /// Subscribes to the given market and returns in the response the specified attributes/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter fields: The market properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    public func subscribe(to epic: IG.Market.Epic, fields: Set<IG.Streamer.Market.Field>, snapshot: Bool = true) -> IG.Streamer.ContinuousPublisher<IG.Streamer.Market> {
        let item = "MARKET:\(epic.rawValue)"
        let properties = fields.map { $0.rawValue }
        let timeFormatter = IG.Streamer.Formatter.time
        
        return self.streamer.channel
            .subscribe(mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .tryMap { (update) in
                do {
                    return try .init(epic: epic, item: item, update: update, timeFormatter: timeFormatter)
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

extension IG.Streamer.Market {
    /// All available fields/properties to query data from a given market.
    public enum Field: String, CaseIterable {
        /// The current market status.
        case status = "MARKET_STATE"
        /// Publis time of last price update.
        case date = "UPDATE_TIME"
        /// Boolean indicating whether prices are delayed.
        case isDelayed = "MARKET_DELAY"
        
        /// The bid price.
        case bid = "BID"
        /// The offer price.
        case ask = "OFFER"
        
        /// Intraday high price.
        case dayHighest = "HIGH"
        /// Opening mid price.
        case dayMid = "MID_OPEN"
        /// Intraday low price.
        case dayLowest = "LOW"
        /// Price change compared with open value.
        case dayChangeNet = "CHANGE"
        /// Price percent change compared with open value.
        case dayChangePercentage = "CHANGE_PCT"
    }
}

extension Set where Element == IG.Streamer.Market.Field {
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
    /// Displays the latests information from a given market.
    public struct Market {
        /// The market epic identifier.
        public let epic: IG.Market.Epic
        /// The current market status.
        public let status: Self.Status?
        
        /// Publis time of last price update.
        public let date: Date?
        /// Boolean indicating whether prices are delayed.
        public let isDelayed: Bool?
        
        /// The bid price.
        public let bid: Decimal?
        /// The offer price.
        public let ask: Decimal?
        
        /// Aggregate data for the current day.
        public let day: Self.Day
        
        /// Designated initializer for a `Streamer` market update.
        fileprivate init(epic: IG.Market.Epic, item: String, update: [String:IG.Streamer.Subscription.Update], timeFormatter: DateFormatter) throws {
            typealias F = Self.Field
            typealias U = IG.Streamer.Formatter.Update
            typealias E = IG.Streamer.Error
            
            self.epic = epic
            
            do {
                self.status = try update[F.status.rawValue]?.value.map(U.toRawType)
                self.date = try update[F.date.rawValue]?.value.map { try U.toTime($0, timeFormatter: timeFormatter) }
                self.isDelayed = try update[F.isDelayed.rawValue]?.value.map(U.toBoolean)
                
                self.bid = try update[F.bid.rawValue]?.value.map(U.toDecimal)
                self.ask = try update[F.ask.rawValue]?.value.map(U.toDecimal)
                
                self.day = try .init(update: update)
            } catch let error as U.Error {
                throw E.invalidResponse(E.Message.parsing(update: error), item: item, update: update, underlying: error, suggestion: E.Suggestion.fileBug)
            } catch let underlyingError {
                throw E.invalidResponse(E.Message.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: E.Suggestion.reviewError)
            }
        }
    }
}

extension IG.Streamer.Market {
    /// The current status of the market.
    public enum Status: String, Codable {
        /// The market is open for trading.
        case tradeable = "TRADEABLE"
        /// The market is closed for the moment. Look at the market's opening hours for further information.
        case closed = "CLOSED"
        case editsOnly = "EDIT"
        case onAuction = "AUCTION"
        case onAuctionNoEdits = "AUCTION_NO_EDIT"
        case offline = "OFFLINE"
        /// The market is suspended for trading temporarily.
        case suspended = "SUSPENDED"
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
        
        fileprivate init(update: [String:IG.Streamer.Subscription.Update]) throws {
            typealias F = IG.Streamer.Market.Field
            typealias U = IG.Streamer.Formatter.Update
            
            self.lowest = try update[F.dayLowest.rawValue]?.value.map(U.toDecimal)
            self.mid = try update[F.dayMid.rawValue]?.value.map(U.toDecimal)
            self.highest = try update[F.dayHighest.rawValue]?.value.map(U.toDecimal)
            self.changeNet = try update[F.dayChangeNet.rawValue]?.value.map(U.toDecimal)
            self.changePercentage = try update[F.dayChangePercentage.rawValue]?.value.map(U.toDecimal)
        }
    }
}

extension IG.Streamer.Market: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = IG.DebugDescription("Streamer Market (\(self.epic.rawValue))")
        result.append("status", self.status)
        result.append("date", self.date, formatter: IG.Streamer.Formatter.time)
        result.append("are prices delayed?", self.isDelayed)
        result.append("price (ask)", self.ask)
        result.append("price (bid)", self.bid)
        result.append("range (high)", self.day.highest)
        result.append("range (mid)", self.day.mid)
        result.append("range (low)", self.day.lowest)
        result.append("change (net)", self.day.changeNet)
        result.append("change (%)", self.day.changePercentage)
        return result.generate()
    }
}
