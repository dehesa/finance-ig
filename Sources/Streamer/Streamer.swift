import ReactiveSwift
import Foundation

/// The Streamer instance is the bridge to the Streaming service provided by IG.
public final class Streamer {
    /// The session (whether real or mocked) managing the streaming connections.
    internal let channel: StreamerMockableChannel
    /// URL root address.
    public let rootURL: URL
    
    /// Holds functionality related to the current streamer session.
    public var session: Streamer.Request.Session { return .init(streamer: self) }
    /// Holds functionality related to markets and charts.
    public var markets: Streamer.Request.Markets { return .init(streamer: self) }
    /// Hold functionality related to accounts.
    public var accounts: Streamer.Request.Accounts { return .init(streamer: self) }
    
    
    /// Creates a `Streamer` instance with the provided credentails and start it right away.
    ///
    /// If you set `autoconnect` to `false` you need to remember to call `connect` on the returned instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    /// - parameter autoconnect: Boolean indicating whether the `connect()` function is called right away, or whether it shall be called later on by the user.
    public convenience init(rootURL: URL, credentials: Streamer.Credentials, autoconnect: Bool = true) {
        let channel = Self.Channel(rootURL: rootURL, credentials: credentials)
        self.init(rootURL: rootURL, channel: channel, autoconnect: autoconnect)
    }
    
    /// Initializer for a Streamer instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter session: Real or mocked session managing the streaming connections.
    /// - parameter autoconnect: Booleain indicating whether the `connect()` function is called right away, or whether it shall be called later on by the user.
    internal init<S:StreamerMockableChannel>(rootURL: URL, channel: S, autoconnect: Bool) {
        self.rootURL = rootURL
        self.channel = channel
        
        guard autoconnect else { return }
        self.channel.connect()
    }
}
