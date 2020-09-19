import Combine
import Foundation

extension Streamer.Request {
    /// Contains all functionality related to Streamer deals/trades.
    @frozen public struct Deals {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        private unowned let _streamer: Streamer
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        @usableFromInline internal init(streamer: Streamer) { self._streamer = streamer }
    }
}

extension Streamer.Request.Deals {
    
    // MARK: TRADE:ACCID
    
    /// Subscribes to the given account and receives updates on positions, working orders, and trade confirmations.
    /// - parameter account: The account identifier.
    /// - parameter fields: The account properties/fields being targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the last deal.
    /// - parameter queue: `DispatchQueue` processing the received values and where the value is forwarded. If `nil`, the internal `Streamer` queue will be used.
    public func subscribe(account: IG.Account.Identifier, fields: Set<Streamer.Deal.Field>, snapshot: Bool = true, queue: DispatchQueue? = nil) -> AnyPublisher<Streamer.Deal,IG.Error> {
        let item = "TRADE:\(account)"
        let properties = fields.map { $0.rawValue }
        let decoder = JSONDecoder()
        
        return self._streamer.channel
            .subscribe(on: queue ?? self._streamer.queue, mode: .distinct, items: [item], fields: properties, snapshot: snapshot)
            .tryMap { [fields] in try Streamer.Deal(account: account, item: item, update: $0, decoder: decoder, fields: fields) }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

extension Streamer.Deal {
    /// Possible fields to subscribe to when querying account data.
    public enum Field: String, CaseIterable {
        /// Trade confirmations for an account.
        case confirmations = "CONFIRMS"
        /// Open positions/workingOrders updates for an account.
        case updates = "OPU"
        /// It doesn't seem to be used anywhere.
//        case workingOrders = "WOU"
    }
}

extension Set where Element == Streamer.Deal.Field {
    /// Returns all queryable fields.
    @_transparent public static var all: Self {
        .init(Element.allCases)
    }
}
