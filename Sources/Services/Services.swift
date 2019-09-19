import ReactiveSwift
import Foundation

/// High-level instance containing all services that can communicate with the IG platform.
public final class Services {
    /// Queue handling all children low-level services.
    private let queue: DispatchQueue
    /// Instance letting you query any API endpoint.
    public let api: IG.API
    /// Instance letting you subscribe to lightsreamer events.
    public let streamer: IG.Streamer
    /// Instance letting you query a databse for caching purposes.
    public let database: IG.DB
    
    /// Designated initializer specifying every single service.
    /// - parameter api: The HTTP API manager.
    /// - parameter streamer: The Lightstreamer event manager.
    /// - parameter database: The Database manager.
    private init(queue: DispatchQueue, api: IG.API, streamer: IG.Streamer, database: IG.DB) {
        self.queue = queue
        self.api = api
        self.streamer = streamer
        self.database = database
    }
    
    /// Factory method for all services, which are log into with the provided user credentials.
    /// - parameter serverURL: The base/root URL for all HTTP endpoint calls. The default URL points to IG's production environment.
    /// - parameter databaseURL: The file URL indicating the location of the caching database.
    /// - parameter key: [API key](https://labs.ig.com/gettingstarted) given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log into an IG account.
    /// - parameter autoconnect: Boolean indicating whether the `connect()` function is called on the `Streamer` instance right away, or whether it shall be called later on by the user.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(serverURL: URL = IG.API.rootURL, databaseURL: URL? = IG.DB.rootURL, key: IG.API.Key, user: IG.API.User, autoconnect: Bool = true) -> SignalProducer<IG.Services,IG.Services.Error> {
        let queue = Self.makeQueue(targetQueue: nil)
        let api = IG.API(rootURL: serverURL, credentials: nil, targetQueue: queue)
        return api.session.login(type: .certificate, key: key, user: user)
            .mapError(Self.Error.api)
            .flatMap(.merge) { _ in Self.make(with: api, queue: queue, databaseURL: databaseURL, autoconnect: autoconnect) }
    }
    
    /// Factory method for all services, which are log into with the provided user token (whether OAuth or Certificate).
    /// - parameter serverURL: The base/root URL for all HTTP endpoint calls. The default URL points to IG's production environment.
    /// - parameter databaseURL: The file URL indicating the location of the caching database.
    /// - parameter key: [API key](https://labs.ig.com/gettingstarted) given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The API token (whether OAuth or certificate) to use to retrieve all user's data.
    /// - parameter autoconnect: Boolean indicating whether the `connect()` function is called on the `Streamer` instance right away, or whether it shall be called later on by the user.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(serverURL: URL = IG.API.rootURL, databaseURL: URL? = IG.DB.rootURL, key: IG.API.Key, token: IG.API.Credentials.Token, autoconnect: Bool = true) -> SignalProducer<IG.Services,IG.Services.Error> {
        let queue = Self.makeQueue(targetQueue: nil)
        let api = IG.API(rootURL: serverURL, credentials: nil, targetQueue: queue)
        
        /// This closure  creates  the othe subservices from the given api key and token.
        /// - requires: The `token` passed to this closure must be valid and already tested. If not, an error event will be sent.
        let signal: (_ token: IG.API.Credentials.Token) -> SignalProducer<IG.Services,IG.Services.Error> = { (token) in
            return api.session.get(key: key, token: token)
                .mapError(Self.Error.api)
                .flatMap(.merge) { (session) -> SignalProducer<IG.Services,IG.Services.Error> in
                    let credentials = IG.API.Credentials(client: session.client, account: session.account, key: key, token: token, streamerURL: session.streamerURL, timezone: session.timezone)
                    api.session.credentials = credentials
                    return Self.make(with: api, queue: queue, databaseURL: databaseURL, autoconnect: autoconnect)
            }
        }
        
        guard token.expirationDate > Date() else {
            switch token.value {
            case .certificate:
                let message = "The given certificate token has expired and it cannot be refreshed"
                let error: IG.API.Error = .invalidRequest(message, suggestion: "Log in with your username and password")
                return .init(error: .api(error: error))
            case .oauth(_, let refreshToken, _,_):
                return api.session.refreshOAuth(token: refreshToken, key: key)
                    .mapError(Self.Error.api)
                    .flatMap(.merge) { signal($0) }
            }
        }
        
        return signal(token)
    }
    
    /// Creates the queue "overlord" managing all services.
    /// - parameter targetQueue: The queue were all services work items end.
    private static func makeQueue(targetQueue: DispatchQueue?) -> DispatchQueue {
        return DispatchQueue(label: Self.reverseDNS, qos: .utility, attributes: .concurrent, autoreleaseFrequency: .never, target: targetQueue)
    }

    /// Creates a streamer from an API instance and package both in a `Services` structure.
    /// - parameter api: The API instance with valid credentials.
    /// - parameter databaseURL: The file URL indicating the location of the caching database.
    /// - parameter autoconnect: Boolean indicating whether the `connect()` function is called on the `Streamer` instance right away, or whether it shall be called later on by the user.
    /// - requires: Valid (not expired) credentials on the given `API` instance or an error event will be sent.
    private static func make(with api: IG.API, queue: DispatchQueue, databaseURL: URL?, autoconnect: Bool) -> SignalProducer<IG.Services,IG.Services.Error> {
        // Check that there is API credentials.
        guard var apiCredentials = api.session.credentials else {
            let error: IG.API.Error = .invalidRequest(IG.API.Error.Message.noCredentials, suggestion: IG.API.Error.Suggestion.logIn)
            return .init(error: .api(error: error))
        }
        // Check that they haven't expired.
        guard apiCredentials.token.expirationDate > Date() else {
            let message = "The given credentials have expired"
            let error: IG.API.Error = .invalidRequest(message, suggestion: "Log in with your username and password")
            return .init(error: .api(error: error))
        }
        
        let subServicesGenerator: ()->Result<IG.Services,IG.Services.Error> = {
            do {
                let secret = try IG.Streamer.Credentials(credentials: apiCredentials)
                let database = try DB(rootURL: databaseURL, targetQueue: queue)
                let streamer = IG.Streamer(rootURL: apiCredentials.streamerURL, credentials: secret, targetQueue: queue, autoconnect: autoconnect)
                return .success(.init(queue: queue, api: api, streamer: streamer, database: database))
            } catch let error as IG.DB.Error {
                return .failure(.database(error: error))
            } catch let error as IG.Streamer.Error {
                return .failure(.streamer(error: error))
            } catch let error as IG.API.Error {
                return .failure(.api(error: error))
            } catch let underlyingError {
                let msg = "An unknown error appeared while creating the \(IG.Streamer.self) and \(IG.DB.self) instance"
                var error: IG.Streamer.Error = .invalidRequest(msg, suggestion: Streamer.Error.Suggestion.fileBug)
                error.underlyingError = underlyingError
                return .failure(.streamer(error: error))
            }
        }
        
        switch apiCredentials.token.value {
        case .oauth:
            return api.session.refreshCertificate()
                .mapError(IG.Services.Error.api)
                .attemptMap {
                    apiCredentials.token = $0
                    return subServicesGenerator()
                }
        case .certificate:
            return .init(subServicesGenerator)
        }
    }
}

extension Services {
    /// The reverse DNS identifier for the `API` instance.
    internal static var reverseDNS: String {
        return IG.bundleIdentifier() + ".services"
    }
    
    /// Wrapper for errors generated in one of the IG services.
    public enum Error: Swift.Error, CustomDebugStringConvertible {
        /// Error produced by the HTTP API subservice.
        case api(error: IG.API.Error)
        /// Error produced by the Lightstreamer subservice.
        case streamer(error: IG.Streamer.Error)
        /// Error produced by the Database subservice.
        case database(error: IG.DB.Error)
        
        public var debugDescription: String {
            switch self {
            case .api(let error): return error.debugDescription
            case .streamer(let error): return error.debugDescription
            case .database(let error): return error.debugDescription
            }
        }
    }
}

extension Services: IG.DebugDescriptable {
    static var printableDomain: String {
        return "IG.\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("queue", self.queue.label)
        result.append("queue QoS", String(describing: self.queue.qos.qosClass))
        result.append("api", self.api.rootURL.absoluteString)
        result.append("streamer", self.streamer.rootURL.absoluteString)
        result.append("databse", self.database.rootURL?.absoluteString ?? ":memory:")
        return result.generate()
    }
}

/// Returns the module's bundle identifier.
internal func bundleIdentifier() -> String {
    guard let identifier = Bundle(for: IG.Services.self).bundleIdentifier else {
        fatalError("The module's bundle identifier hasn't been set")
    }
    return identifier
}
