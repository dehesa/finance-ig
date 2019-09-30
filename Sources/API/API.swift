import Foundation

/// The API instance is the bridge to the HTTP endpoints provided by the platform.
///
/// It allows you to authenticate on the platforms and it stores the credentials for priviledge endpoints (which are most of them).
/// APIs where there are no explicit `note` in the documentation require stored credentials.
/// - note: You can create as many API instances as you want, but each instance contains its on URL Session; thus you may want to have a single API instance doing all your endpoint calling.
public final class API {
    /// URL root address.
    public let rootURL: URL
    /// The queue processing all API requests and responses.
    private let queue: DispatchQueue
    /// The URL Session instance for performing HTTPS requests.
    internal let channel: URLSession
    /// It holds data and functionality related to the user's session.
    public internal(set) var session: IG.API.Request.Session
    /// It holds functionality related to the user's applications.
    public var applications: IG.API.Request.Applications { return .init(api: self) }
    /// It holds functionality related to the user's accounts.
    public var accounts: IG.API.Request.Accounts { return .init(api: self) }
    /// It holds functionality related to the user's activity & transactions, and market prices.
    public var history: IG.API.Request.History { return .init(api: self) }
    /// It holds functionality related to market navigation nodes.
    public var nodes: IG.API.Request.Nodes { return .init(api: self) }
    /// It holds functionality related to platform market.
    public var markets: IG.API.Request.Markets { return .init(api: self) }
    /// It holds functionality related to watchlists.
    public var watchlists: IG.API.Request.Watchlists { return .init(api: self) }
    /// It holds functionality related to positions.
    public var positions: IG.API.Request.Positions { return .init(api: self) }
    /// It holds functionality related to working orders.
    public var workingOrders: IG.API.Request.WorkingOrders { return .init(api: self) }
    
    /// Initializer for an API instance, giving you the default options.
    ///
    /// Each API instance has its own serial `DispatchQueue`. The queue provided in this initializer is the target queue for the created instance's queue.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter queue: The target queue on which to process the `API` requests and responses.
    public convenience init(rootURL: URL, credentials: IG.API.Credentials?, targetQueue: DispatchQueue?) {
        let dispatchQueue = DispatchQueue(label: Self.reverseDNS, qos: .utility, autoreleaseFrequency: .workItem, target: targetQueue)
        let operationQueue = OperationQueue(name: dispatchQueue.label + ".operationQueue", underlyingQueue: dispatchQueue)
        let channel = URLSession(configuration: IG.API.defaultSessionConfigurations, delegate: nil, delegateQueue: operationQueue)
        self.init(rootURL: rootURL, credentials: credentials, channel: channel, queue: dispatchQueue)
    }
    
    /// Designated initializer for an API instance, giving you the default options.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter channel: The low-level API endpoint handler.
    /// - parameter queue: The `DispatchQueue` actually handling the `API` requests and responses. It is also the delegate `OperationQueue`'s underlying queue.
    internal init(rootURL: URL, credentials: IG.API.Credentials?, channel: URLSession, queue: DispatchQueue) {
        self.rootURL = rootURL
        self.queue = queue
        self.channel = channel
        self.session = .init(credentials: credentials)
        self.session.api = self
    }
    
    deinit {
        self.channel.invalidateAndCancel()
    }
}

extension IG.API {
    /// The root address for the IG endpoints.
    public static let rootURL = URL(string: "https://api.ig.com/gateway/deal")!
    
    /// The reverse DNS identifier for the `API` instance.
    internal static var reverseDNS: String {
        return IG.Bundle.identifier + ".api"
    }
    
    /// Default configuration for the underlying URLSession
    internal static var defaultSessionConfigurations: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.networkServiceType = .default
        configuration.allowsCellularAccess = true
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpShouldUsePipelining = true
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return configuration
    }
}

extension IG.API: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.Bundle.name).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("root URL", self.rootURL.absoluteString)
        result.append("queue", self.queue.label)
        result.append("queue QoS", String(describing: self.queue.qos.qosClass))
        return result.generate()
    }
}
