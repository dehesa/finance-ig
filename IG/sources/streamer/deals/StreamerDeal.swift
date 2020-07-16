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
    public func subscribeToDeals(account: IG.Account.Identifier, fields: Set<Streamer.Deal.Field>, snapshot: Bool = true) -> AnyPublisher<Streamer.Deal,Streamer.Error> {
        let (item, properties) = ("TRADE:".appending(account.rawValue), fields.map { $0.rawValue })
        let decoder = JSONDecoder()
        
        return self.streamer.channel.subscribe(on: self.streamer.queue, mode: .distinct, item: item, fields: properties, snapshot: snapshot)
            .tryMap { (update) in
                do {
                    return try .init(account: account, item: item, update: update, decoder: decoder)
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

extension Streamer.Deal {
    /// Possible fields to subscribe to when querying account data.
    public enum Field: String, CaseIterable {
        /// Trade confirmations for an account.
        case confirmations = "CONFIRMS"
        /// Open position updates for an account.
        case positions = "OPU"
        /// Working order updates for an account.
        case workingOrders = "WOU"
    }
}

// MARK: Respose Entities

extension Streamer {
    /// A deal confirmation update.
    public struct Deal {
        /// Account identifier.
        public let account: IG.Account.Identifier
        /// Confirmation update.
        public let confirmation: Streamer.Confirmation?
        /// Open position update.
        public let position: Streamer.Position?
        /// Working order update.
        public let workingOrder: Streamer.WorkingOrder?
        
        fileprivate init(account: IG.Account.Identifier, item: String, update: Streamer.Packet, decoder: JSONDecoder) throws {
            typealias F = Self.Field
            typealias E = Streamer.Error
            
            self.account = account
            self.confirmation = try update[F.confirmations.rawValue]?.value.map {
                try decoder.decode(Streamer.Confirmation.self, from: .init($0.utf8))
            }
            self.position = try update[F.positions.rawValue]?.value.map {
                try decoder.decode(Streamer.Position.self, from: .init($0.utf8))
            }
            self.workingOrder = try update[F.workingOrders.rawValue]?.value.map {
                try decoder.decode(Streamer.WorkingOrder.self, from: .init($0.utf8))
            }
        }
    }
}

//extension Streamer.Deal: CustomDebugStringConvertible {
//    public var debugDescription: String {
//        "\(self.account.rawValue) \(self.confirmation.debugDescription)"
//    }
//}
//
