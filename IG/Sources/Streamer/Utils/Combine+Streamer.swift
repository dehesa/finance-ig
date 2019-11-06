import Combine

extension IG.Streamer {
    /// List of custom publishers and types used with the `Combine` framework.
    public enum Publishers {
        /// Publisher emitting a single value followed by a successful completion
        ///
        /// The following behavior is guaranteed when you see this type:
        /// - the publisher will emit a single value followed by a succesful completion, or
        /// - the publisher will emit a `Streamer.Error` failure.
        ///
        /// If a failure is emitted, no value was sent previously.
        public typealias Discrete<T> = Combine.AnyPublisher<T,IG.Streamer.Error>
        /// Publisher that can send zero, one, or many values followed by a successful completion.
        ///
        /// A failure may be forwarded when processing a value.
        public typealias Continuous<T> = Combine.AnyPublisher<T,IG.Streamer.Error>
    }
}
