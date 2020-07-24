import Combine
import Foundation

extension Streamer.Request {
    /// Contains all functionality related to Streamer deals/trades.
    public struct Deals {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        internal unowned let streamer: Streamer
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        @usableFromInline internal init(streamer: Streamer) { self.streamer = streamer }
    }
}

extension Streamer.Request.Deals {
    
    // MARK: TRADE:ACCID
    
    /// Subscribes to the given account and receives updates on positions, working orders, and trade confirmations.
    public func subscribeToDeals(account: IG.Account.Identifier, fields: Set<Streamer.Deal.Field>, snapshot: Bool = true) -> AnyPublisher<Streamer.Deal,IG.Error> {
        let item = "TRADE:\(account)"
        let properties = fields.map { $0.rawValue }
        let decoder = JSONDecoder()
        
        return self.streamer.channel
            .subscribe(on: self.streamer.queue, mode: .distinct, item: item, fields: properties, snapshot: snapshot)
            .tryMap { try Streamer.Deal(account: account, item: item, update: $0, decoder: decoder) }
            .mapStreamError(item: item, fields: fields)
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
