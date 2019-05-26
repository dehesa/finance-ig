import Foundation

/// The API instance is the bridge to the HTTP endpoints provided by the platform.
///
/// It allows you to authenticate on the platforms and it stores the credentials for priviledge endpoints (which are most of them).
/// APIs where there are no explicit `note` in the documentation require stored credentials.
/// - note: You can create as many API instances as you want, but each instance contains its on URL Session; thus you may want to have a single API instance doing all your endpoint calling.
public final class API {
    /// Session credentials used to call priviledge endpoints.
    private var sessionCredentials: API.Credentials?
    /// The URL Session instance for performing HTTPS requests.
    internal let sessionURL: URLMockableSession
    /// URL root address.
    public let rootURL: URL
    
    /// Designated initializer allowing you to change the internal URL session.
    ///
    /// This initializer is used for testing purposes; that is why is marked with `internal` access.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter session: URL session used to perform all HTTP requests.
    /// - parameter credentials: Credentials used to authenticate the endpoints. Pass `nil` if the credentials are unknown at creation time.
    internal init(rootURL: URL, session: URLMockableSession, credentials: API.Credentials? = nil) {
        self.rootURL = rootURL
        self.sessionURL = session
        self.sessionCredentials = credentials
    }
    
    /// Initializer for an API instance, giving you the default options.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter configurations: URL session configuration properties. By default, you get a non-cached, non-cookies, pipeline and secure URL session configuration.
    public convenience init(rootURL: URL, credentials: API.Credentials?, configurations: URLSessionConfiguration = API.defaultSessionConfigurations) {
        self.init(rootURL: rootURL, session: URLSession(configuration: configurations), credentials: credentials)
    }
    
    deinit {
        self.sessionURL.invalidateAndCancel()
    }

    /// Returns credentials needed on most API endpoints.
    /// - returns: Session credentials (whether CST or OAuth).
    /// - throws: `API.Error.invalidCredentials` if there were no credentials stored.
    public func credentials() throws -> API.Credentials {
        return try self.sessionCredentials ?! API.Error.invalidCredentials(nil, message: "No credentials found.")
    }
    
    /// Updates the current credentials (if any) with a new set of credentials.
    /// - parameter credentials: The new set of credentials to be stored within this API instance.
    public func updateCredentials(_ credentials: API.Credentials) {
        self.sessionCredentials = credentials
    }
    
    /// Removes the current credentials (leaving none behind).
    ///
    /// After the call to this method, no endpoint requiring credentials can be executed.
    public func removeCredentials() {
        self.sessionCredentials = nil
    }
    
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
