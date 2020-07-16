import Combine
import Foundation
import Decimals

extension Streamer.Request {
    /// Contains all functionality related to Streamer markets.
    public struct Markets {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        internal unowned let streamer: Streamer
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        @usableFromInline internal init(streamer: Streamer) { self.streamer = streamer }
    }
}

extension Streamer.Request.Markets {
    
    // MARK: MARKET:EPIC
    
    /// Subscribes to the given market and returns in the response the specified attributes/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter fields: The market properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    public func subscribe(epic: IG.Market.Epic, fields: Set<Streamer.Market.Field>, snapshot: Bool = true) -> AnyPublisher<Streamer.Market,Streamer.Error> {
        let (item, properties) = ("MARKET:\(epic.rawValue)", fields.map { $0.rawValue })
        let timeFormatter = DateFormatter.londonTime
        
        return self.streamer.channel
            .subscribe(on: self.streamer.queue, mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .tryMap { (update) in
                do {
                    return try .init(epic: epic, item: item, update: update, timeFormatter: timeFormatter)
                } catch var error as Streamer.Error {
                    if case .none = error.item { error.item = item }
                    if case .none = error.fields { error.fields = properties }
                    throw error
                } catch let underlyingError {
                    throw Streamer.Error.invalidResponse(.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: .reviewError)
                }
            }.mapError(Streamer.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension Streamer.Market {
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

extension Set where Element == Streamer.Market.Field {
    /// Returns a set with all the dayly related fields.
    @_transparent public static var day: Self {
        Self.init([.dayLowest, .dayMid, .dayHighest, .dayChangeNet, .dayChangePercentage])
    }
    
    /// Returns all queryable fields.
    @_transparent public static var all: Self {
        .init(Element.allCases)
    }
}

// MARK: Response Entities

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
        
        /// Designated initializer for a `Streamer` market update.
        fileprivate init(epic: IG.Market.Epic, item: String, update: Streamer.Packet, timeFormatter: DateFormatter) throws {
            typealias F = Self.Field
            typealias U = Streamer.Update
            typealias E = Streamer.Error
            
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

extension Streamer.Market {
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
        public let lowest: Decimal64?
        /// The mid price of the day.
        public let mid: Decimal64?
        /// The highest price of the day
        public let highest: Decimal64?
        /// Net change from open price to current.
        public let changeNet: Decimal64?
        /// Daily percentage change.
        public let changePercentage: Decimal64?
        
        fileprivate init(update: Streamer.Packet) throws {
            typealias F = Streamer.Market.Field
            typealias U = Streamer.Update
            
            self.lowest = try update[F.dayLowest.rawValue]?.value.map(U.toDecimal)
            self.mid = try update[F.dayMid.rawValue]?.value.map(U.toDecimal)
            self.highest = try update[F.dayHighest.rawValue]?.value.map(U.toDecimal)
            self.changeNet = try update[F.dayChangeNet.rawValue]?.value.map(U.toDecimal)
            self.changePercentage = try update[F.dayChangePercentage.rawValue]?.value.map(U.toDecimal)
        }
    }
}

extension Streamer.Market: IG.DebugDescriptable {
    internal static var printableDomain: String { "\(Streamer.printableDomain).\(Self.self)" }
    
    public var debugDescription: String {
        var result = IG.DebugDescription("\(Self.printableDomain) (\(self.epic.rawValue))")
        result.append("status", self.status)
        result.append("date", self.date, formatter: DateFormatter.londonTime)
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
