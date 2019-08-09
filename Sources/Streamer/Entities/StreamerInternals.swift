import Foundation

extension Streamer {
    /// List of request data needed to make subscriptions.
    public enum Request {}
}

extension DispatchQoS {
    /// Quality of Service for real time messaging.
    internal static let realTimeMessaging = DispatchQoS(qosClass: .userInitiated, relativePriority: 0)
}

extension Streamer {
    /// Possible Lightstreamer modes.
    internal enum Mode: String {
        /// Lightstreamer MERGE mode.
        case merge = "MERGE"
        /// Lightstreamer DISTINCT mode.
        case distinct = "DISTINCT"
        /// Lightstreamer RAW mode.
        case raw = "RAW"
        /// Lightstreamer COMMAND mode.
        case command = "COMMAND"
    }
}
