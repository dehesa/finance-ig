#if os(macOS) && arch(x86_64)
import Lightstreamer_macOS_Client
#elseif os(macOS)

#elseif os(iOS)
import Lightstreamer_iOS_Client
#elseif os(tvOS)
import Lightstreamer_tvOS_Client
#else
#error("OS currently not supported")
#endif
import Foundation

extension Streamer {
    /// A deal confirmation update.
    public struct Deal {
        /// Account identifier.
        public let account: IG.Account.Identifier
        /// Confirmation reception.
        public let confirmation: Streamer.Confirmation?
        /// Open position or working order update.
        public let update: Streamer.Update?
    }
}

#if (os(macOS) && arch(x86_64)) || os(iOS) || os(tvOS)

fileprivate typealias F = Streamer.Deal.Field

internal extension Streamer.Deal {
    /// Designated initializer.
    /// - parameter account: Identifier for the account where the deal took place.
    /// - parameter item: The type of update (i.e. whether a confirmation or a position/workingOrder update).
    /// - parameter decoder: The JSON decoder being used to decode the packet.
    /// - parameter fields: The packet fields the user is interested on.
    /// - throws: `IG.Error` exclusively.
    init(account: IG.Account.Identifier, item: String, update: LSItemUpdate, decoder: JSONDecoder, fields: Set<Field>) throws {
        self.account = account
        
        do {
            if fields.contains(F.confirmations), let c = update.decodeIfPresent(String.self, forKey: F.confirmations) {
                self.confirmation = try decoder.decode(Streamer.Confirmation.self, from: .init(c.utf8))
            } else { self.confirmation = nil }
            
            if fields.contains(F.updates), let u = update.decodeIfPresent(String.self, forKey: F.updates) {
                self.update = try decoder.decode(Streamer.Update.self, from: .init(u.utf8))
            } else { self.update = nil }
        } catch let error as IG.Error {
            throw error
        } catch let error {
            throw IG.Error.failedToDecode(with: error, account: account)
        }
    }
}

private extension IG.Error {
    /// Error raised when an underlying Swift error (which is not an IG.Error) has been thrown.
    /// - parameter error: The underlying decoding error.
    /// - parameter account: The account identifier where the deal took place.
    static func failedToDecode(with error: Swift.Error, account: IG.Account.Identifier) -> Self {
        Self(.streamer(.invalidResponse), "An error was encountered when trying to decode a Streamer deal.", help: "Review the internal error.", underlying: error, info: ["Account": account])
    }
}

#else

internal extension Streamer.Deal {
    init(account: IG.Account.Identifier, item: String, update: Any, decoder: JSONDecoder, fields: Set<Field>) throws {
        fatalError()
    }
}

#endif
