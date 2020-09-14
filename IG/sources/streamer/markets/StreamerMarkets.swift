import Combine
import Foundation
import Decimals

extension Streamer.Request {
    /// Contains all functionality related to Streamer markets.
    @frozen public struct Markets {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        private unowned let _streamer: Streamer
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        @usableFromInline internal init(streamer: Streamer) { self._streamer = streamer }
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
    /// - parameter queue: `DispatchQueue` processing the received values and where the value is forwarded. If `nil`, the internal `Streamer` queue will be used. 
    public func subscribe(epic: IG.Market.Epic, fields: Set<Streamer.Market.Field>, snapshot: Bool = true, queue: DispatchQueue? = nil) -> AnyPublisher<Streamer.Market,IG.Error> {
        let item = "MARKET:\(epic)"
        let properties = fields.map { $0.rawValue }
        let timeFormatter = DateFormatter.londonTime
        
        return self._streamer.channel
            .subscribe(on: queue ?? self._streamer.queue, mode: .merge, items: [item], fields: properties, snapshot: snapshot)
            .tryMap { [fields] in try Streamer.Market(epic: epic, update: $0, timeFormatter: timeFormatter, fields: fields) }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Subscribes to the multiple markets and returns in the response the specified attributes/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter epics: The epics identifying the targeted markets.
    /// - parameter fields: The market properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - parameter queue: `DispatchQueue` processing the received values and where the value is forwarded. If `nil`, the internal `Streamer` queue will be used. 
    public func subscribe(epics: Set<IG.Market.Epic>, fields: Set<Streamer.Market.Field>, snapshot: Bool = true, queue: DispatchQueue? = nil) -> AnyPublisher<Streamer.Market,IG.Error> {
        guard !epics.isEmpty else { return Empty().eraseToAnyPublisher() }
        guard epics.count > 1 else { return self.subscribe(epic: epics.first.unsafelyUnwrapped, fields: fields, snapshot: snapshot) }
        
        let items = epics.map { "MARKET:\($0)" }
        let properties = fields.map { $0.rawValue }
        let timeFormatter = DateFormatter.londonTime
        
        return self._streamer.channel
            .subscribe(on: queue ?? self._streamer.queue, mode: .merge, items: items, fields: properties, snapshot: snapshot)
            .tryMap { [fields] in
                guard let item = $0.itemName, let epic = IG.Market.Epic(item.split(separator: ":").dropFirst().joined(separator: ":")) else {
                    throw IG.Error._invalid(itemName: $0.itemName)
                }
                return try Streamer.Market(epic: epic, update: $0, timeFormatter: timeFormatter, fields: fields)
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

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

private extension IG.Error {
    /// Error raised when the epic reveived as an update item is invalid.
    static func _invalid(itemName: String?) -> Self {
        Self(.streamer(.invalidResponse), "The Lightstreamer item name received couldn't be matched to a supported epic.", help: "Review the received item name.", info: ["Received item": itemName ?? ""])
    }
}
