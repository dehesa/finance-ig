import ReactiveSwift
import Foundation

extension IG.Streamer.Request.Charts {
    
    // MARK: CHART:EPIC:TICK
    
    /// Subscribes to a given market and returns every tick data.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter fields: The chart properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market. explicitly call `connect()`.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(to epic: IG.Market.Epic, fields: Set<IG.Streamer.Chart.Tick.Field>, snapshot: Bool = true) -> SignalProducer<IG.Streamer.Chart.Tick,IG.Streamer.Error> {
        typealias E = IG.Streamer.Error
        
        let item = "CHART:\(epic.rawValue):TICK"
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(mode: .distinct, item: item, fields: properties, snapshot: snapshot)
            .attemptMap { (update) in
                do {
                    return .success(try .init(epic: epic, item: item, update: update))
                } catch var error as E {
                    if case .none = error.item { error.item = item }
                    if case .none = error.fields { error.fields = properties }
                    return .failure(error)
                } catch let underlyingError {
                    let error = E(.invalidResponse, E.Message.unknownParsing, suggestion: E.Suggestion.reviewError, item: item, fields: properties, underlying: underlyingError)
                    return .failure(error)
                }
        }
    }
}

// MARK: - Supporting Entities

// MARK: Request Entities

extension IG.Streamer.Chart.Tick {
    /// Possible fields to subscribe to when querying market data.
    public enum Field: String, CaseIterable {
        /// Update time.
        case date = "UTM"
        /// Bid price
        case bid = "BID"
        /// Offer price.
        case ask = "OFR"
        // /// Last traded price.
        // case lastTradedPrice = "LTP"
        /// Last traded volume.
        case volume = "LTV"
        // /// Incremental trading volume.
        // case volumeIncremental = "TTV"
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

extension Set where Element == IG.Streamer.Chart.Tick.Field {
    /// Returns a set with all the dayly related fields.
    public static var day: Self {
        return Self.init([.dayLowest, .dayMid, .dayHighest, .dayChangeNet, .dayChangePercentage])
    }
    
    /// Returns all queryable fields.
    public static var all: Self {
        return .init(Element.allCases)
    }
}

extension IG.Streamer.Chart {
    /// Chart data aggregated by a given time interval.
    public struct Tick {
        /// The market epic identifier.
        public let epic: IG.Market.Epic
        /// The date of the information.
        public let date: Date?
        /// The tick bid price.
        public let bid: Decimal?
        /// The tick ask/offer price.
        public let ask: Decimal?
        /// Last traded volume.
        public let volume: Decimal?
        /// Aggregate data for the current day.
        public let day: Self.Day
        
        internal init(epic: IG.Market.Epic, item: String, update: [String:IG.Streamer.Subscription.Update]) throws {
            typealias F = Self.Field
            typealias U = IG.Streamer.Formatter.Update
            typealias E = IG.Streamer.Error
            
            self.epic = epic
            
            do {
                self.date = try update[F.date.rawValue]?.value.map(U.toEpochDate)
                self.bid = try update[F.bid.rawValue]?.value.map(U.toDecimal)
                self.ask = try update[F.ask.rawValue]?.value.map(U.toDecimal)
                self.volume = try update[F.volume.rawValue]?.value.map(U.toDecimal)
                self.day = try .init(update: update)
            } catch let error as U.Error {
                throw E.invalidResponse(E.Message.parsing(update: error), item: item, update: update, underlying: error, suggestion: E.Suggestion.bug)
            } catch let underlyingError {
                throw E.invalidResponse(E.Message.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: E.Suggestion.reviewError)
            }
        }
    }
}

extension IG.Streamer.Chart.Tick {
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
            typealias F = IG.Streamer.Chart.Tick.Field
            typealias U = IG.Streamer.Formatter.Update
            
            self.lowest = try update[F.dayLowest.rawValue]?.value.map(U.toDecimal)
            self.mid = try update[F.dayMid.rawValue]?.value.map(U.toDecimal)
            self.highest = try update[F.dayHighest.rawValue]?.value.map(U.toDecimal)
            self.changeNet = try update[F.dayChangeNet.rawValue]?.value.map(U.toDecimal)
            self.changePercentage = try update[F.dayChangePercentage.rawValue]?.value.map(U.toDecimal)
        }
    }
}

extension IG.Streamer.Chart.Tick: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = IG.DebugDescription("Streamer Chart Tick (\(self.epic))")
        result.append("date", self.date, formatter: IG.Streamer.Formatter.time)
        result.append("volume", self.volume)
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
