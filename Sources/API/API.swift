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
    let channel: URLMockableSession
    
    /// It holds data and functionality related to the user's session.
    public internal(set) lazy var session = API.Request.Session(api: self)
    /// It holds functionality related to the user's applications.
    public private(set) lazy var applications = API.Request.Applications(api: self)
    /// It holds functionality related to the user's accounts.
    public private(set) lazy var accounts = API.Request.Accounts(api: self)
    
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
    init(rootURL: URL, channel: URLMockableSession, credentials: API.Credentials? = nil) {
        self.rootURL = rootURL
        self.channel = channel
        
        guard let credentials = credentials else { return }
        self.session.credentials = credentials
    }
    
    deinit {
        self.channel.invalidateAndCancel()
    }
}

extension API {
    /// Default configuration for the underlying URLSession
    public static var defaultSessionConfigurations: URLSessionConfiguration {
        return URLSessionConfiguration.ephemeral.set {
            $0.networkServiceType = .default
            $0.allowsCellularAccess = true
            $0.httpCookieAcceptPolicy = .never
            $0.httpCookieStorage = nil
            $0.httpShouldSetCookies = false
            $0.httpShouldUsePipelining = true
            $0.urlCache = nil
            $0.requestCachePolicy = .reloadIgnoringLocalCacheData
            $0.waitsForConnectivity = false
            $0.tlsMinimumSupportedProtocol = .tlsProtocol12
        }
    }
}
