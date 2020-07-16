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
    @inlinable public final var price: Streamer.Request.Price { .init(streamer: self) }
    /// Namespace for subscriptions related to trades/deals.
    @inlinable public final var deals: Streamer.Request.Deals { .init(streamer: self) }
    
    /// Creates a `Streamer` instance with the provided credentails and start it right away.
    ///
    /// If you set `autoconnect` to `false` you need to remember to call `connect` on the returned instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    /// - parameter targetQueue: The target queue on which to process the `Streamer` requests and responses.
    /// - note: Each subscription will have its own serial queue and the QoS will get inherited from `queue`.
    public convenience init(rootURL: URL, credentials: Streamer.Credentials, targetQueue: DispatchQueue?) {
        let processingQueue = DispatchQueue(label: Self.reverseDNS + ".queue",  qos: .utility, attributes: .concurrent, autoreleaseFrequency: .inherit, target: targetQueue)
        let channel = Self.Channel(rootURL: rootURL, credentials: credentials)
        self.init(rootURL: rootURL, channel: channel, queue: processingQueue)
    }
    
    /// Initializer for a Streamer instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter channel: The low-level streaming connection manager.
    /// - parameter queue: The queue on which to process the `Streamer` requests and responses.
    internal init(rootURL: URL, channel: Streamer.Channel, queue: DispatchQueue) {
        self.rootURL = rootURL
        self.queue = queue
        self.channel = channel
    }
}

extension Streamer {
    /// The reverse DNS identifier for the `Streamer` instance.
    internal static var reverseDNS: String {
        Bundle.IG.identifier + ".streamer"
    }
}

extension Streamer: IG.DebugDescriptable {
    internal static var printableDomain: String { "\(Bundle.IG.name).\(Self.self)" }
    
    public final var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("root URL", self.rootURL.absoluteString)
        result.append("processing queue", self.queue.label)
        result.append("processing queue QoS", String(describing: self.queue.qos.qosClass))
        result.append("lightstreamer", Streamer.Channel.lightstreamerVersion)
        result.append("connection status", self.channel.status)
        return result.generate()
    }
}
