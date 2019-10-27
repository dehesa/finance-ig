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

extension IG.Streamer {
    /// List of custom publishers.
    public enum Publishers {
        /// Type erased `Combine.Future` where a single value and a completion or a failure will be sent.
        /// This behavior is guaranteed when you see this type.
        public typealias Discrete<T> = Combine.AnyPublisher<T,IG.Streamer.Error>
        /// Publisher that can send zero, one, or many values followed by a successful completion.
        public typealias Continuous<T> = Combine.AnyPublisher<T,IG.Streamer.Error>
    }
}
