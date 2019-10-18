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
    
    /// It holds data and functionality related to the user's session.
    public final var session: IG.API.Request.Session { return .init(api: self) }
    /// It holds functionality related to the user's applications.
    public final var applications: IG.API.Request.Applications { return .init(api: self) }
    /// It holds functionality related to the user's accounts.
    public final var accounts: IG.API.Request.Accounts { return .init(api: self) }
    /// It holds functionality related to the user's activity & transactions, and market prices.
    public final var history: IG.API.Request.History { return .init(api: self) }
    /// It holds functionality related to market navigation nodes.
    public final var nodes: IG.API.Request.Nodes { return .init(api: self) }
    /// It holds functionality related to platform market.
    public final var markets: IG.API.Request.Markets { return .init(api: self) }
    /// It holds functionality related to watchlists.
    public final var watchlists: IG.API.Request.Watchlists { return .init(api: self) }
    /// It holds functionality related to positions.
    public final var positions: IG.API.Request.Positions { return .init(api: self) }
    /// It holds functionality related to working orders.
    public final var workingOrders: IG.API.Request.WorkingOrders { return .init(api: self) }
    
    /// Initializer for an API instance, giving you the default options.
    ///
    /// Each API instance has its own serial `DispatchQueue`. The queue provided in this initializer is the target queue for the created instance's queue.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter queue: The target queue on which to process the `API` requests and responses.
    public convenience init(rootURL: URL, credentials: IG.API.Credentials?, targetQueue: DispatchQueue?) {
        let priviledgeQueue = DispatchQueue(label: Self.reverseDNS + ".priviledge", qos: .utility, autoreleaseFrequency: .never, target: targetQueue)
        let processingQueue = DispatchQueue(label: Self.reverseDNS + ".processing", qos: .utility, autoreleaseFrequency: .workItem, target: targetQueue)
        
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
    /// The root address for the IG endpoints.
    public static let rootURL = URL(string: "https://api.ig.com/gateway/deal")!
    
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
