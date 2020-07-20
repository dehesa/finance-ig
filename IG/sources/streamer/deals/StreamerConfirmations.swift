import Combine
import Foundation

extension Streamer.Request.Deals {
    
    // MARK: TRADE:ACCID
    
    /// Subscribes to the given account and receives trade confirmations.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter account: The Account identifier.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - returns: Signal producer that can be started at any time.
    public func subscribeToConfirmations(account: IG.Account.Identifier, snapshot: Bool = true) -> AnyPublisher<Streamer.Confirmation,Streamer.Error> {
        fatalError()
//        return self.streamer.channel
//            .subscribe(on: self.streamer.queue, mode: .distinct, item: item, fields: properties, snapshot: snapshot)
//            .filter {
//                guard let payload = $0[Streamer.Deal._Field.confirmations.rawValue] else { return false }
//                return payload.isUpdated && payload.value != nil
//            }.tryMap { (update) in
//                do {
//                    return try .init(account: account, item: item, update: update)
//                } catch var error as Streamer.Error {
//                    if case .none = error.item { error.item = item }
//                    if case .none = error.fields { error.fields = properties }
//                    throw error
//                } catch let underlyingError {
//                    throw Streamer.Error.invalidResponse(.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: .reviewError)
//                }
//            }.mapError(Streamer.Error.transform)
//            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

// MARK: Respose Entities

extension Streamer {
    ///
    public struct Confirmation: Decodable {
        ///
        #warning("Complete me")
    }
}
