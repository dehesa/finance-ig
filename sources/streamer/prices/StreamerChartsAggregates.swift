import Combine
import Foundation
import Decimals

extension Streamer.Request {
    /// Contains all functionality related to Streamer charts.
    @frozen public struct Prices {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        @usableFromInline internal unowned let streamer: Streamer
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        @usableFromInline internal init(streamer: Streamer) { self.streamer = streamer }
    }
}

extension Streamer.Request.Prices {
    
    // MARK: CHART:EPIC:SCALE
    
    /// Subscribes to a given market and returns aggreagated chart data for a specific time interval.
    ///
    /// For example, if subscribed to EUR/USD on the 5-minute interval; the data received will be the one of the last 5-minute candle and some statistics of the day.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter interval: The aggregation interval for the candle.
    /// - parameter fields: The chart properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market. explicitly call `connect()`.
    /// - parameter queue: `DispatchQueue` processing the received values and where the value is forwarded. If `nil`, the internal `Streamer` queue will be used.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(epic: IG.Market.Epic, interval: Streamer.Chart.Aggregated.Interval, fields: Set<Streamer.Chart.Aggregated.Field>, snapshot: Bool = true, queue: DispatchQueue? = nil) -> AnyPublisher<Streamer.Chart.Aggregated,IG.Error> {
        let item = "CHART:\(epic):\(interval.description)"
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(on: queue ?? self.streamer.queue, mode: .merge, items: [item], fields: properties, snapshot: snapshot)
            .tryMap { [fields] in try Streamer.Chart.Aggregated(epic: epic, interval: interval, update: $0, fields: fields) }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Subscribes to multiple markets and returns aggreagated chart data for a specific time interval.
    ///
    /// For example, if subscribed to EUR/USD on the 5-minute interval; the data received will be the one of the last 5-minute candle and some statistics of the day.
    /// - parameter epics: The epics identifying the targeted markets.
    /// - parameter interval: The aggregation interval for the candle.
    /// - parameter fields: The chart properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market. explicitly call `connect()`.
    /// - parameter queue: `DispatchQueue` processing the received values and where the value is forwarded. If `nil`, the internal `Streamer` queue will be used. 
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(epics: Set<IG.Market.Epic>, interval: Streamer.Chart.Aggregated.Interval, fields: Set<Streamer.Chart.Aggregated.Field>, snapshot: Bool = true, queue: DispatchQueue? = nil) -> AnyPublisher<Streamer.Chart.Aggregated,IG.Error> {
        guard !epics.isEmpty else { return Empty().eraseToAnyPublisher() }
        guard epics.count > 1 else { return self.subscribe(epic: epics.first.unsafelyUnwrapped, interval: interval, fields: fields, snapshot: snapshot) }
        
        let items = epics.map { "CHART:\($0):\(interval.description)" }
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(on: queue ?? self.streamer.queue, mode: .merge, items: items, fields: properties, snapshot: snapshot)
            .tryMap { [fields] in
                #if (os(macOS) && arch(x86_64)) || os(iOS) || os(tvOS)
                guard let item = $0.itemName, let epic = IG.Market.Epic(item.split(separator: ":").dropFirst().dropLast().joined(separator: ":")) else {
                    throw IG.Error._invalid(itemName: $0.itemName)
                }
                return try Streamer.Chart.Aggregated(epic: epic, interval: interval, update: $0, fields: fields)
                #else
                fatalError()
                #endif
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

extension Streamer.Chart.Aggregated {
    /// The time interval used for aggregation.
    public enum Interval: CustomStringConvertible {
        case second, minute, minute5, hour
        
        public var description: String {
            switch self {
            case .second: return "SECOND"
            case .minute: return "1MINUTE"
            case .minute5: return "5MINUTE"
            case .hour: return "HOUR"
            }
        }
        
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

extension Streamer.Chart.Aggregated {
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

extension Set where Element == Streamer.Chart.Aggregated.Field {
    /// Returns a set with all the candle related fields.
    @_transparent public static var candle: Self {
        Self.init([.date, .openBid, .openAsk, .closeBid, .closeAsk,
                          .lowestBid, .lowestAsk, .highestBid, .highestAsk,
                          .isFinished, .numTicks, .volume])
    }
    
    /// Returns a set with all the dayly related fields.
    @_transparent public static var day: Self {
        Self.init([.dayLowest, .dayMid, .dayHighest, .dayChangeNet, .dayChangePercentage])
    }
    
    /// Returns all queryable fields.
    @_transparent public static var all: Self {
        .init(Element.allCases)
    }
}

private extension IG.Error {
    /// Error raised when the epic reveived as an update item is invalid.
    static func _invalid(itemName: String?) -> Self {
        Self(.streamer(.invalidResponse), "The Lightstreamer item name received couldn't be matched to a supported epic.", help: "Review the received item name.", info: ["Received item": itemName ?? ""])
    }
}
