import ReactiveSwift
import Foundation

extension Streamer.Request.Confirmations {
    
    // MARK: TRADE:ACCID
    
    /// Subscribes to the given account and receives updates on positions, working orders, and trade confirmations.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter account: The Account identifier.
    /// - parameter fields: The account properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(to account: IG.Account.Identifier, snapshot: Bool = true) -> SignalProducer<Streamer.Deal,Streamer.Error> {
        let item = "TRADE:".appending(account.rawValue)
        let properties = [Streamer.Deal.Field.confirmations.rawValue]
        
        return self.streamer.channel
            .subscribe(mode: .distinct, item: item, fields: properties, snapshot: snapshot)
            .ignore {
                guard let update = $0[Streamer.Deal.Field.confirmations.rawValue] else { return true }
                return !update.isUpdated || update.value == nil
            }.attemptMap { (update) in
                do {
                    return .success(try .init(account: account, item: item, update: update))
                } catch var error as Streamer.Error {
                    if case .none = error.item { error.item = item }
                    if case .none = error.fields { error.fields = properties }
                    return .failure(error)
                } catch let underlyingError {
                    let error = Streamer.Error(.invalidResponse, Streamer.Error.Message.unknownParsing, suggestion: Streamer.Error.Suggestion.reviewError, item: item, fields: properties, underlying: underlyingError)
                    return .failure(error)
                }
        }
    }
}

// MARK: - Supporting Entities

extension Streamer.Request {
    /// Contains all functionality related to Streamer accounts.
    public struct Confirmations {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        fileprivate unowned let streamer: Streamer
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: Streamer) {
            self.streamer = streamer
        }
    }
}

// MARK: Request Entities

extension Streamer.Deal {
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

extension Streamer {
    /// A deal confirmation update.
    public struct Deal {
        /// Account identifier.
        public let account: IG.Account.Identifier
        /// Confirmation update.
        public let confirmation: IG.Confirmation
        
        internal init(account: IG.Account.Identifier, item: String, update: [String:Streamer.Subscription.Update]) throws {
            self.account = account
            guard let confirmationUpdate = update[Self.Field.confirmations.rawValue] else {
                throw Streamer.Error.invalidResponse("The confirmation field wasn't found in confirmation updates", item: item, update: update, underlying: nil, suggestion: Streamer.Error.Suggestion.bug)
            }
            
            guard let confirmationString = confirmationUpdate.value else {
                throw Streamer.Error.invalidResponse("The confirmation value wasn't found in confirmation updates", item: item, update: update, underlying: nil, suggestion: Streamer.Error.Suggestion.bug)
            }
            
            let decoder = JSONDecoder()
            do {
                self.confirmation = try decoder.decode(IG.Confirmation.self, from: .init(confirmationString.utf8))
            } catch let error as Streamer.Formatter.Update.Error {
                throw Streamer.Error.invalidResponse(Streamer.Error.Message.parsing(update: error), item: item, update: update, underlying: error, suggestion: Streamer.Error.Suggestion.bug)
            } catch let underlyingError {
                throw Streamer.Error.invalidResponse(Streamer.Error.Message.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: Streamer.Error.Suggestion.reviewError)
            }
        }
    }
}

extension Streamer.Deal: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(self.account.rawValue) \(self.confirmation.debugDescription)"
    }
}
