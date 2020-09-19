import Foundation

extension API {
    /// Watchlist data.
    public struct Watchlist: Identifiable {
        /// Watchlist identifier.
        public let id: String
        /// Watchlist given name.
        public let name: String
        /// Indicates whether the watchlist belong to the user or is one predefined by the system.
        public let isOwnedBySystem: Bool
        /// Indicates whether the watchlist can be altered by the user.
        public let isEditable: Bool
        /// Indicates whether the watchlist can be deleted by the user.
        public let isDeleteable: Bool
    }
}

// MARK: -

extension API.Watchlist: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, name
        case isOwnedBySystem = "defaultSystemWatchlist"
        case isEditable = "editable"
        case isDeleteable = "deleteable"
    }
}
