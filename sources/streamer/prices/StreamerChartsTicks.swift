import Combine
import Foundation
import Decimals

extension Streamer.Request.Prices {
    
    // MARK: CHART:EPIC:TICK
    
    /// Subscribes to a given market and returns every tick data.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter fields: The chart properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market. explicitly call `connect()`.
    /// - parameter queue: `DispatchQueue` processing the received values and where the value is forwarded. If `nil`, the internal `Streamer` queue will be used.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(epic: IG.Market.Epic, fields: Set<Streamer.Chart.Tick.Field>, snapshot: Bool = true, queue: DispatchQueue? = nil) -> AnyPublisher<Streamer.Chart.Tick,IG.Error> {
        let item = "CHART:\(epic):TICK"
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(on: queue ?? self.streamer.queue, mode: .distinct, items: [item], fields: properties, snapshot: snapshot)
            .tryMap { [fields] in try Streamer.Chart.Tick(epic: epic, item: item, update: $0, fields: fields) }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Subscribes to multiple markets and returns every tick data.
    /// - parameter epics: The epics identifying the targeted markets.
    /// - parameter fields: The chart properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market. explicitly call `connect()`.
    /// - parameter queue: `DispatchQueue` processing the received values and where the value is forwarded. If `nil`, the internal `Streamer` queue will be used.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(epics: Set<IG.Market.Epic>, fields: Set<Streamer.Chart.Tick.Field>, snapshot: Bool = true, queue: DispatchQueue? = nil) -> AnyPublisher<Streamer.Chart.Tick,IG.Error> {
        guard !epics.isEmpty else { return Empty().eraseToAnyPublisher() }
        guard epics.count > 1 else { return self.subscribe(epic: epics.first.unsafelyUnwrapped, fields: fields, snapshot: snapshot) }
        
        let items = epics.map { "CHART:\($0):TICK" }
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(on: queue ?? self.streamer.queue, mode: .distinct, items: items, fields: properties, snapshot: snapshot)
            .tryMap { [fields] in
                guard let item = $0.itemName, let epic = IG.Market.Epic(item.split(separator: ":").dropFirst().joined(separator: ":")) else {
                    throw IG.Error._invalid(itemName: $0.itemName)
                }
                return try Streamer.Chart.Tick(epic: epic, item: item, update: $0, fields: fields)
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

extension Streamer.Chart.Tick {
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

extension Set where Element == Streamer.Chart.Tick.Field {
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
