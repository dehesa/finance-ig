import Foundation

/// The API instance is the bridge to the HTTP endpoints provided by the platform.
///
/// It allows you to authenticate on the platforms and it stores the credentials for priviledge endpoints (which are most of them).
/// APIs where there are no explicit `note` in the documentation require stored credentials.
/// - note: You can create as many API instances as you want, but each instance contains its on URL Session; thus you may want to have a single API instance doing all your endpoint calling.
public final class API {
    /// URL root address.
    public final let rootURL: URL
    /// The queue processing and delivering server values.
    internal final let queue: DispatchQueue
    /// The URL Session instance for performing HTTPS requests.
    internal final let channel: API.Channel
    
    /// Namespace for endpoints related to the current API session (e.g. log in/out, refresh token, etc.).
    @inlinable public final var session: API.Request.Session { .init(api: self) }
    /// Namespace for endpoints related to the user's account/s (e.g. account info, transactions, activity, etc.).
    @inlinable public final var accounts: API.Request.Accounts { .init(api: self) }
    /// Namespace for endpoints related to the IG markets (e.g. market info, snapshots, etc.).
    @inlinable public final var markets: API.Request.Markets { .init(api: self) }
    /// Namespace for endpoints related to price data point retrieval (e.g. return all data points for EUR/USD market with resolution of 1 minute).
    @inlinable public final var price: API.Request.Price { .init(api: self) }
    /// Namespace for endpoints related to open positions (e.g. create a position, tweak it, or close it).
    @inlinable public final var positions: API.Request.Positions { .init(api: self) }
    /// Namespace for endpoints related to open working orders (e.g. create a working order, tweak it, or close it).
    @inlinable public final var workingOrders: API.Request.WorkingOrders { .init(api: self) }
    /// Namespace for endpoints related to IG nodes; that is what IG uses to navigate its tree of available markets.
    @inlinable public final var nodes: API.Request.Nodes { .init(api: self) }
    /// Namespace for endpoints related to watchlist management (e.g. create/remove watchlist, add/remove markets to it, etc.).
    @inlinable public final var watchlists: API.Request.Watchlists { .init(api: self) }
    /// Namespace for endpoints related to endpoints scrapped from IG website (e.g. economic calendar).
    @inlinable public final var scrapped: API.Request.Scrapped { .init(api: self) }
    
    /// Initializer for an API instance, giving you the default options.
    ///
    /// Each API instance has its own serial `DispatchQueue`. The queue provided in this initializer is the target queue for the created instance's queue.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter targetQueue: The target queue on which to process the `API` requests and responses.
    /// - parameter qos: The Quality of Service for the API processing queue.
    public convenience init(rootURL: URL, credentials: API.Credentials?, targetQueue: DispatchQueue?, qos: DispatchQoS) {
        // - warning: If the `URLSession` is ever to have a delegate, `processingQueue` must be serial. Otherwise, the delegate message wouldn't be ordered.
        let processingQueue = DispatchQueue(label: Self.reverseDNS + ".queue", qos: qos, attributes: .init(), autoreleaseFrequency: .inherit, target: targetQueue)
        let operationQueue = OperationQueue(name: Self.reverseDNS + ".operationQueue", underlyingQueue: processingQueue)
        let session = URLSession(configuration: API.Channel.defaultSessionConfigurations, delegate: nil, delegateQueue: operationQueue)
        self.init(rootURL: rootURL, credentials: credentials, queue: processingQueue, session: session)
    }
    
    /// Designated initializer used for both real and mocked usage.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter session: The URL session used to call the real (or mocked) endpoints.
    /// - parameter queue: The `DispatchQueue` actually handling the `API` requests and responses. It is also the delegate `OperationQueue`'s underlying queue.
    internal init(rootURL: URL, credentials: API.Credentials?, queue: DispatchQueue, session: URLSession) {
        self.rootURL = rootURL
        self.queue = queue
        self.channel = .init(session: session, credentials: credentials, scheduler: queue)
    }
}

extension API {
    /// The root address for the publicly accessible endpoints.
    public static let rootURL = URL(string: "https://api.ig.com/gateway/deal")!
    /// The root URL for the hidden endpoints.
    public static let scrappedRootURL = URL(string: "https://deal.ig.com")!
    /// The reverse DNS identifier for the `API` instance.
    internal static var reverseDNS: String { Bundle.IG.identifier + ".api" }
}

extension API: IG.DebugDescriptable {
    internal static var printableDomain: String { "\(Bundle.IG.name).\(Self.self)" }
    
    public final var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("root URL", self.rootURL.absoluteString)
        result.append("queue", self.queue.label)
        result.append("queue QoS", String(describing: self.queue.qos.qosClass))
        return result.generate()
    }
}
