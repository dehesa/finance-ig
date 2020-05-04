import Combine

extension IG.Streamer {
    /// List of request data needed to make subscriptions.
    public enum Request {}

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
