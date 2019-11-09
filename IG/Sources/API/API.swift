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
    private final let queue: DispatchQueue
    /// The URL Session instance for performing HTTPS requests.
    internal final let channel: IG.API.Channel
    
    /// Namespace for endpoints related to the current API session (e.g. log in/out, refresh token, etc.).
    public final var session: IG.API.Request.Session { return .init(api: self) }
    /// Namespace for endpoints related to the user's account/s (e.g. account info, transactions, activity, etc.).
    public final var accounts: IG.API.Request.Accounts { return .init(api: self) }
    /// Namespace for endpoints related to the IG markets (e.g. market info, snapshots, etc.).
    public final var markets: IG.API.Request.Markets { return .init(api: self) }
    /// Namespace for endpoints related to price data point retrieval (e.g. return all data points for EUR/USD market with resolution of 1 minute).
    public final var price: IG.API.Request.Price { return .init(api: self) }
    /// Namespace for endpoints related to open positions (e.g. create a position, tweak it, or close it).
    public final var positions: IG.API.Request.Positions { return .init(api: self) }
    /// Namespace for endpoints related to open working orders (e.g. create a working order, tweak it, or close it).
    public final var workingOrders: IG.API.Request.WorkingOrders { return .init(api: self) }
    /// Namespace for endpoints related to IG nodes; that is what IG uses to navigate its tree of available markets.
    public final var nodes: IG.API.Request.Nodes { return .init(api: self) }
    /// Namespace for endpoints related to watchlist management (e.g. create/remove watchlist, add/remove markets to it, etc.).
    public final var watchlists: IG.API.Request.Watchlists { return .init(api: self) }
    /// Namespace for endpoints related to endpoints scrapped from IG website (e.g. economic calendar).
    public final var scrapped: IG.API.Request.Scrapped { return .init(api: self) }
    
    /// Initializer for an API instance, giving you the default options.
    ///
    /// Each API instance has its own serial `DispatchQueue`. The queue provided in this initializer is the target queue for the created instance's queue.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter queue: The target queue on which to process the `API` requests and responses.
    public convenience init(rootURL: URL, credentials: IG.API.Credentials?, targetQueue: DispatchQueue?) {
        let priviledgeQueue = DispatchQueue(label: Self.reverseDNS + ".priviledge", qos: .utility, autoreleaseFrequency: .inherit, target: targetQueue)
        let processingQueue = DispatchQueue(label: Self.reverseDNS + ".processing", qos: .utility, autoreleaseFrequency: .inherit, target: targetQueue)
        
        let operationQueue = OperationQueue.init(name: processingQueue.label + ".operationQueue", underlyingQueue: processingQueue)
        let session = URLSession(configuration: IG.API.Channel.defaultSessionConfigurations, delegate: nil, delegateQueue: operationQueue)
        let channel = IG.API.Channel(session: session, queue: priviledgeQueue, credentials: credentials)
        
        self.init(rootURL: rootURL, channel: channel, queue: processingQueue)
    }
    
    /// Designated initializer for an API instance, giving you the default options.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter channel: The low-level API endpoint handler.
    /// - parameter queue: The `DispatchQueue` actually handling the `API` requests and responses. It is also the delegate `OperationQueue`'s underlying queue.
    internal init(rootURL: URL, channel: IG.API.Channel, queue: DispatchQueue) {
        self.rootURL = rootURL
        self.queue = queue
        self.channel = channel
    }
}

extension IG.API {
    /// The root address for the publicly accessible endpoints.
    public static let rootURL = URL(string: "https://api.ig.com/gateway/deal")!
    /// The root URL for the hidden endpoints.
    public static let scrappedRootURL = URL(string: "https://deal.ig.com")!
    
    /// The reverse DNS identifier for the `API` instance.
    internal static var reverseDNS: String {
        return IG.Bundle.identifier + ".api"
    }
}

extension IG.API: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.Bundle.name).\(Self.self)"
    }
    
    public final var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("root URL", self.rootURL.absoluteString)
        result.append("queue", self.queue.label)
        result.append("queue QoS", String(describing: self.queue.qos.qosClass))
        return result.generate()
    }
}
