import Foundation

/// The API instance is the bridge to the HTTP endpoints provided by the platform.
///
/// It allows you to authenticate on the platforms and it stores the credentials for priviledge endpoints (which are most of them). APIs where there are no explicit `note` in the documentation require stored credentials.
/// - note: You can create as many API instances as you want, but each instance contains its on URL session; thus you may want to have a single API instance doing all your calls.
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
    @inlinable public final var prices: API.Request.Prices { .init(api: self) }
    /// Namespace for endpoints related to working orders, open positions, and trade confirmations.
    @inlinable public final var deals: API.Request.Deals { .init(api: self) }
    /// Namespace for endpoints related to IG nodes; that is what IG uses to navigate its tree of available markets.
    @inlinable public final var nodes: API.Request.Nodes { .init(api: self) }
    /// Namespace for endpoints related to watchlist management (e.g. create/remove watchlist, add/remove markets to it, etc.).
    @inlinable public final var watchlists: API.Request.Watchlists { .init(api: self) }
    
    /// Convenience initializer setting the root URL and initial credentials for the API instance.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter queue: The queue used to process the requests and responses. If `nil`, the system will create a serial queue.
    public convenience init(rootURL: URL = API.rootURL, credentials: API.Credentials? = nil, queue: DispatchQueue? = nil) {
        let queue = queue ?? DispatchQueue(label: Bundle.IG.identifier + ".api.queue", qos: .utility)
        let session = URLSession(configuration: API.Channel.defaultSessionConfigurations, delegate: nil, delegateQueue: OperationQueue(underlying: queue))
        self.init(rootURL: rootURL, credentials: credentials, queue: queue, session: session)
    }
    
    /// Designated initializer used for regular and mocked usage.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter queue: The `DispatchQueue` actually handling the requests and responses. It is also the delegate `OperationQueue`'s underlying queue.
    /// - parameter session: The URL session used to call the real (or mocked) endpoints. 
    internal init(rootURL: URL, credentials: API.Credentials?, queue: DispatchQueue, session: URLSession) {
        (self.rootURL, self.queue) = (rootURL, queue)
        self.channel = API.Channel(session: session, credentials: credentials, scheduler: queue)
    }
}

extension API {
    /// The root URL for the production endpoints.
    @inlinable public static var rootURL: URL { URL(string: "https://api.ig.com/gateway/deal").unsafelyUnwrapped }
    /// The root URL for the demo accounts.
    @inlinable public static var demoRootURL: URL { URL(string: "https://demo-api.ig.com/gateway/deal").unsafelyUnwrapped }
    /// The root URL for the hidden endpoints.
    @inlinable public static var scrappedRootURL: URL { URL(string: "https://deal.ig.com").unsafelyUnwrapped }
}
