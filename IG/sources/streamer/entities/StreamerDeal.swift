#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#else
#error("OS currently not supported")
#endif
import Foundation

extension Streamer {
    /// A deal confirmation update.
    public struct Deal {
        /// Account identifier.
        public let account: IG.Account.Identifier
        /// Confirmation update.
        public let confirmation: Streamer.Confirmation?
        /// Open position update.
        public let update: Streamer.Update?
    }
}

fileprivate typealias F = Streamer.Deal.Field

internal extension Streamer.Deal {
    /// - throws: `IG.Error` exclusively.
    init(account: IG.Account.Identifier, item: String, update: LSItemUpdate, decoder: JSONDecoder) throws {
        self.account = account
        
        do {
            self.confirmation = try update.decodeIfPresent(String.self, forKey: F.confirmations).map {
                try decoder.decode(Streamer.Confirmation.self, from: .init($0.utf8))
            }
            
            self.update = try update.decodeIfPresent(String.self, forKey: F.updates).map {
                try decoder.decode(Streamer.Update.self, from: .init($0.utf8))
            }
        } catch let error as IG.Error {
            throw error
        } catch let error {
            throw IG.Error.failedToDecode(with: error, account: account)
        }
    }
}

private extension IG.Error {
    /// Error raised when an underlying Swift error (which is not an IG.Error) has been thrown.
    static func failedToDecode(with error: Swift.Error, account: IG.Account.Identifier) -> Self {
        Self(.streamer(.invalidResponse), "An error was encountered when trying to decode a Streamer deal.", help: "Review the internal error.", underlying: error, info: ["Account": account])
    }
}
