import Combine
import Foundation

extension IG.Streamer.Request {
    /// Contains all functionality related to Streamer deals.
    public struct Confirmations {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        fileprivate unowned let streamer: IG.Streamer
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: IG.Streamer) {
            self.streamer = streamer
        }
    }
}

extension IG.Streamer.Request.Confirmations {
    
    // MARK: TRADE:ACCID
    
    /// Subscribes to the given account and receives updates on positions, working orders, and trade confirmations.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter account: The Account identifier.
    /// - parameter fields: The account properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(to account: IG.Account.Identifier, snapshot: Bool = true) -> IG.Streamer.ContinuousPublisher<IG.Streamer.Deal> {
        let item = "TRADE:".appending(account.rawValue)
        let properties = [IG.Streamer.Deal.Field.confirmations.rawValue]
        
        return self.streamer.channel
            .subscribe(mode: .distinct, item: item, fields: properties, snapshot: snapshot)
            .receive(on: self.streamer.queue)
            .filter {
                guard let payload = $0[IG.Streamer.Deal.Field.confirmations.rawValue] else { return false }
                return payload.isUpdated && payload.value != nil
            }.tryMap { (update) in
                do {
                    return try .init(account: account, item: item, update: update)
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

extension IG.Streamer.Deal {
    /// Possible fields to subscribe to when querying account data.
    fileprivate enum Field: String, CaseIterable {
        /// Trade confirmations for an account.
        case confirmations = "CONFIRMS"
//        /// Open position updates for an account.
//        case positions = "OPU"
//        /// Working order updates for an account.
//        case workingOrders = "WOU"
    }
}

// MARK: Respose Entities

extension IG.Streamer {
    /// A deal confirmation update.
    public struct Deal {
        /// Account identifier.
        public let account: IG.Account.Identifier
        /// Confirmation update.
        public let confirmation: IG.Confirmation
        
        internal init(account: IG.Account.Identifier, item: String, update: [String:IG.Streamer.Subscription.Update]) throws {
            typealias E = IG.Streamer.Error
            
            self.account = account
            guard let confirmationUpdate = update[Self.Field.confirmations.rawValue] else {
                throw E.invalidResponse("The confirmation field wasn't found in confirmation updates", item: item, update: update, underlying: nil, suggestion: E.Suggestion.fileBug)
            }
            
            guard let confirmationString = confirmationUpdate.value else {
                throw E.invalidResponse("The confirmation value wasn't found in confirmation updates", item: item, update: update, underlying: nil, suggestion: E.Suggestion.fileBug)
            }
            
            let decoder = JSONDecoder()
            do {
                self.confirmation = try decoder.decode(IG.Confirmation.self, from: .init(confirmationString.utf8))
            } catch let error as IG.Streamer.Formatter.Update.Error {
                throw E.invalidResponse(E.Message.parsing(update: error), item: item, update: update, underlying: error, suggestion: E.Suggestion.fileBug)
            } catch let underlyingError {
                throw E.invalidResponse(E.Message.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: E.Suggestion.reviewError)
            }
        }
    }
}

extension IG.Streamer.Deal: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(self.account.rawValue) \(self.confirmation.debugDescription)"
    }
}
