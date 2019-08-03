import ReactiveSwift
import Foundation

/// The API instance is the bridge to the HTTP endpoints provided by the platform.
///
/// It allows you to authenticate on the platforms and it stores the credentials for priviledge endpoints (which are most of them).
/// APIs where there are no explicit `note` in the documentation require stored credentials.
/// - note: You can create as many API instances as you want, but each instance contains its on URL Session; thus you may want to have a single API instance doing all your endpoint calling.
public final class API {
    /// URL root address.
    public let rootURL: URL
    /// The URL Session instance for performing HTTPS requests.
    internal let channel: APIMockableChannel
    /// Represents this instances lifetime. It will be triggered when the instance is deallocated.
    internal let lifetime: Lifetime
    /// The token that when triggered, will trigger all `Lifetime` observers. It is triggered (automatically) when the instance is deallocated.
    private let lifetimeToken: Lifetime.Token
    
    /// It holds data and functionality related to the user's session.
    public internal(set) var session: API.Request.Session
    /// It holds functionality related to the user's applications.
    public var applications: API.Request.Applications { return .init(api: self) }
    /// It holds functionality related to the user's accounts.
    public var accounts: API.Request.Accounts { return .init(api: self) }
    /// It holds functionality related to the user's activity.
    public var activity: API.Request.Activity { return .init(api: self) }
    /// It holds functionality related to the user's transactions.
    public var transactions: API.Request.Transactions { return .init(api: self) }
    /// It holds functionality related to price history queries.
    public var prices: API.Request.Price { return .init(api: self) }
    /// It holds functionality related to market navigation nodes.
    public var nodes: API.Request.Nodes { return .init(api: self) }
    /// It holds functionality related to platform market.
    public var markets: API.Request.Markets { return .init(api: self) }
    /// It holds functionality related to watchlists.
    public var watchlists: API.Request.Watchlists { return .init(api: self) }
    /// It holds functionality related to positions.
    public var positions: API.Request.Positions { return .init(api: self) }
    /// It holds functionality related to working orders.
    public var workingOrders: API.Request.WorkingOrders { return .init(api: self) }
    
    /// Initializer for an API instance, giving you the default options.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter configurations: URL session configuration properties. By default, you get a non-cached, non-cookies, pipeline and secure URL session configuration.
    public convenience init(rootURL: URL, credentials: API.Credentials?, configuration: URLSessionConfiguration = API.defaultSessionConfigurations) {
        let channel = URLSession(configuration: configuration)
        self.init(rootURL: rootURL, channel: channel, credentials: credentials)
    }
    
    /// Designated initializer allowing you to change the internal URL session.
    ///
    /// This initializer is used for testing purposes; that is why is marked with `internal` access.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter channel: URL session used to perform all HTTP requests.
    /// - parameter credentials: Credentials used to authenticate the endpoints. Pass `nil` if the credentials are unknown at creation time.
    internal init<A:APIMockableChannel>(rootURL: URL, channel: A, credentials: API.Credentials? = nil) {
        self.rootURL = rootURL
        (self.lifetime, self.lifetimeToken) = Lifetime.make()
        self.channel = channel
        self.session = .init(credentials: credentials)
        self.session.api = self
    }
    
    deinit {
        self.channel.invalidateAndCancel()
    }
}

extension API {
    /// The root address for the IG endpoints.
    public static let rootURL = URL(string: "https://api.ig.com/gateway/deal")!
    
    /// Default configuration for the underlying URLSession
    public static var defaultSessionConfigurations: URLSessionConfiguration {
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
        configuration.tlsMinimumSupportedProtocol = .tlsProtocol12
        return configuration
    }
}
