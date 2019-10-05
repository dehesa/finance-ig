import Combine
import Foundation

extension IG.Streamer {
    /// List of request data needed to make subscriptions.
    public enum Request {}
    
    /// Type erased `Combine.Future` where a single value and a completion or a failure will be sent.
    /// This behavior is guaranteed when you see this type.
    public typealias Future<T> = AnyPublisher<T,IG.Streamer.Error>
    /// Publisher that can send zero, one, or many values followed by a successful completion.
    ///
    /// This type is typically semantically used for paginated requests.
    public typealias ContinuousPublisher<T> = AnyPublisher<T,IG.Streamer.Error>
}

extension IG.Streamer {
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
