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
    internal let channel: URLMockableSession
    
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
    /// It holds functionality related to watchlists.
    public var positions: API.Request.Positions { return .init(api: self) }
    
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
    internal init(rootURL: URL, channel: URLMockableSession, credentials: API.Credentials? = nil) {
        self.rootURL = rootURL
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
    
    /// Domain namespace retaining anything related to API requests.
    public enum Request {}
    /// Domain namespace retaining anything related to API responses.
    public enum Response {}
    
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

extension API {
    /// HTTP related constants.
    internal enum HTTP {
        /// The HTTP method supported by this API
        /// - seealso: [w3.org website specifying the RFC2616 protocol](http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html)
        enum Method: String {
            /// POST method ask the resource at the given URI to do something with the provided entity. Usually, it creates a new entity.
            case post = "POST"
            /// GET method is used to retrieve information.
            case get = "GET"
            /// PUT method stores an entity at a URI. It is used to create a new entity or update an existing one.
            case put = "PUT"
            /// DELETE method request a resource to be removed.
            case delete = "DELETE"
        }
        
        /// HTTP header constants used by IG endpoints.
        enum Header {
            /// HTTP header keys used throughout IG endpoints.
            enum Key: String {
                /// Header key pointing to an IG account identifier.
                case account = "IG-ACCOUNT-ID"
                /// Header key pointing to an API key identifying an application/developer.
                case apiKey = "X-IG-API-KEY"
                /// OAuth header key.
                case authorization = "Authorization"
                /// Certificate header key.
                case clientSessionToken = "CST"
                /// Header key pointing at the date of package generation.
                case date = "Date"
                /// The platform specific request identifier.
                case requestId = "X-REQUEST-ID"
                /// They type of content in the package.
                case requestType = "Content-Type"
                /// The type of content is expected in the response package.
                case responseType = "Accept"
                /// Platform specific security key.
                case securityToken = "X-SECURITY-TOKEN"
                /// Platform specific versioning system for API endpoints.
                case version = "Version"
                /// Specifically used in the platform to change the type of HTTP method.
                case _method = "_method"
            }
            
            /// HTTP header values used throughout IG endpoints.
            enum Value {
                /// The type of content types supported by this API
                enum ContentType: String {
                    /// A JSON content type is expected.
                    case json = "application/json; charset=UTF-8"
                }
            }
        }
    }
    
    /// Namespace for all JSON related constants (pertaining the API).
    internal enum JSON {
        /// Namesapce for JSON decoding keys.
        enum DecoderKey {
            /// Key for JSON decoders under which the URL response will be stored.
            static let responseHeader = CodingUserInfoKey(rawValue: "urlResponse")!
            /// Key for JSON decoders under which the response date is stored.
            static let responseDate = CodingUserInfoKey(rawValue: "urlResponseDate")!
            /// Key for JSON decoders under which a date formatter will be stored.
            static let dateFormatter = CodingUserInfoKey(rawValue: "dateFormatter")!
        }
    }
}
