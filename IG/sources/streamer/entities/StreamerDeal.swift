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
    ///
    init(account: IG.Account.Identifier, item: String, update: Streamer.Packet, decoder: JSONDecoder) throws {
        self.account = account
        
        self.confirmation = try update.decodeIfPresent(String.self, forKey: F.confirmations).map {
            try decoder.decode(Streamer.Confirmation.self, from: .init($0.utf8))
        }
        
        self.update = try update.decodeIfPresent(String.self, forKey: F.updates).map {
            try decoder.decode(Streamer.Update.self, from: .init($0.utf8))
        }
    }
}
