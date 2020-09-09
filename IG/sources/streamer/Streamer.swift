import Foundation

/// The Streamer instance is the bridge to the Streaming service provided by IG.
public final class Streamer {
    /// URL root address.
    public final let rootURL: URL
    /// The queue managing all Streamer responses.
    internal final let queue: DispatchQueue
    /// The underlying instance (whether real or mocked) managing the streaming connections.
    internal final let channel: Streamer.Channel
    
    /// Namespace for the functionality related to managing a LightStreamer connection (e.g. open/close, status, reset, etc.).
    @inlinable public final var session: Streamer.Request.Session { .init(streamer: self) }
    /// Namespace for subscriptions related to a user's account.
    @inlinable public final var accounts: Streamer.Request.Accounts { .init(streamer: self) }
    /// Namespace for subscriptions related to market information.
    @inlinable public final var markets: Streamer.Request.Markets { .init(streamer: self) }
    /// Namespace for subscriptions related to prices.
    @inlinable public final var prices: Streamer.Request.Prices { .init(streamer: self) }
    /// Namespace for subscriptions related to trades/deals.
    @inlinable public final var deals: Streamer.Request.Deals { .init(streamer: self) }
    
    /// Creates a `Streamer` instance with the provided credentails and start it right away.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    /// - parameter queue: The queue used to process the requests and responses. If `nil`, the system will create an appropriate queue.
    /// - note: Each subscription will have its own serial queue and the QoS will get inherited from `queue`.
    public convenience init(rootURL: URL, credentials: Streamer.Credentials, queue: DispatchQueue? = nil) {
        let processingQueue = queue ?? DispatchQueue(label: Bundle.IG.identifier + ".streamer.queue",  qos: .default)
        let channel = Self.Channel(rootURL: rootURL, credentials: credentials)
        self.init(rootURL: rootURL, channel: channel, queue: processingQueue)
    }
    
    /// Initializer for a Streamer instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter channel: The low-level streaming connection manager.
    /// - parameter queue: The queue on which to process the `Streamer` requests and responses.
    internal init(rootURL: URL, channel: Streamer.Channel, queue: DispatchQueue) {
        (self.rootURL, self.queue) = (rootURL, queue)
        self.channel = channel
    }
}
