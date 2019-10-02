import Foundation

/// The Streamer instance is the bridge to the Streaming service provided by IG.
public final class Streamer {
    /// URL root address.
    public let rootURL: URL
    /// The queue managing all Streamer requests and responses.
    private let queue: DispatchQueue
    /// The underlying instance (whether real or mocked) managing the streaming connections.
    internal let channel: IG.StreamerMockableChannel
    
    /// Holds functionality related to the current streamer session.
    public var session: IG.Streamer.Request.Session { return .init(streamer: self) }
    /// Holds functionality related to markets.
    public var markets: IG.Streamer.Request.Markets { return .init(streamer: self) }
    #warning("Streamer: Uncomment")
//    /// Holds functionality related to charts.
//    public var charts: IG.Streamer.Request.Charts { return .init(streamer: self) }
//    /// Hold functionality related to accounts.
//    public var accounts: IG.Streamer.Request.Accounts { return .init(streamer: self) }
//    /// Hold functionality related to deals (positions, working orders, and confirmations).
//    public var confirmations: IG.Streamer.Request.Confirmations { return .init(streamer: self) }
    
    /// Creates a `Streamer` instance with the provided credentails and start it right away.
    ///
    /// If you set `autoconnect` to `false` you need to remember to call `connect` on the returned instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    /// - parameter targetQueue: The target queue on which to process the `Streamer` requests and responses.
    /// - note: Each subscription will have its own serial queue and the QoS will get inherited from `queue`.
    public convenience init(rootURL: URL, credentials: IG.Streamer.Credentials, targetQueue: DispatchQueue?) {
        let queue = DispatchQueue(label: Self.reverseDNS, qos: .utility, autoreleaseFrequency: .never, target: targetQueue)
        let channel = Self.Channel(rootURL: rootURL, credentials: credentials, queue: queue)
        self.init(rootURL: rootURL, channel: channel, queue: queue)
    }
    
    /// Initializer for a Streamer instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter channel: The low-level streaming connection manager.
    /// - parameter queue: The queue on which to process the `Streamer` requests and responses.
    internal init<Session:IG.StreamerMockableChannel>(rootURL: URL, channel: Session, queue: DispatchQueue) {
        self.rootURL = rootURL
        self.queue = queue
        self.channel = channel
    }

    deinit {
        _ = self.channel.unsubscribeAll()
        _ = self.channel.disconnect()
    }
}

extension IG.Streamer {
    /// The reverse DNS identifier for the `Streamer` instance.
    internal static var reverseDNS: String {
        return IG.Bundle.identifier + ".streamer"
    }
}

extension IG.Streamer: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.Bundle.name).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("root URL", self.rootURL.absoluteString)
        result.append("queue", self.queue.label)
        result.append("queue QoS", String(describing: self.queue.qos.qosClass))
        result.append("lightstreamer", IG.Streamer.Channel.lightstreamerVersion)
        result.append("connection status", self.channel.status)
        return result.generate()
    }
}
