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
    public func subscribe(epic: IG.Market.Epic, fields: Set<Streamer.Market.Field>, snapshot: Bool = true) -> AnyPublisher<Streamer.Market,IG.Error> {
        let item = "MARKET:\(epic.rawValue)"
        let properties = fields.map { $0.rawValue }
        let timeFormatter = DateFormatter.londonTime
        
        return self.streamer.channel
            .subscribe(on: self.streamer.queue, mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .tryMap { try Streamer.Market(epic: epic, update: $0, timeFormatter: timeFormatter) }
            .mapError {
                switch $0 {
                case let error as IG.Error:
                    error.errorUserInfo["Item"] = item
                    error.errorUserInfo["Fields"] = fields
                    return error
                case let error:
                    return IG.Error(.streamer(.invalidResponse), "Unable to parse response.", help: "Review the error and contact the repo maintainer.", underlying: error, info: ["Item": item, "Fields": fields])
                }
            }.eraseToAnyPublisher()
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
