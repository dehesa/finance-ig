import Conbini
import Combine
import Foundation

/// High-level instance containing all services that can communicate with the IG platform.
public final class Services {
    /// Queue handling all children low-level services.
    public let queue: DispatchQueue
    /// Instance letting you query any API endpoint.
    public let api: API
    /// Instance letting you subscribe to lightsreamer events.
    public let streamer: Streamer
    /// Instance letting you query a databse for caching purposes.
    public let database: Database
    
    /// Designated initializer specifying every single service.
    ///
    /// By calling this initializer you are forfeiting the conveniences provided by the other initializers; that is, validate credentials, logging in the API, set all queues to a concurrent target queue (for performance reasons).
    /// Please, take note that this initializer do not assures the API is already log in or any credential input is valid
    /// - parameter api: The HTTP API manager.
    /// - parameter streamer: The Lightstreamer event manager.
    /// - parameter database: The Database manager.
    public init(queue: DispatchQueue, api: API, streamer: Streamer, database: Database) {
        self.queue = queue
        self.api = api
        self.streamer = streamer
        self.database = database
    }
    
    /// Factory method for all services, which are log into with the provided user credentials.
    ///
    /// The `streamer` service still requires a further `streamer.session.connect()` call.
    /// - parameter databaseLocation: The location of the database (whether "in-memory" or file system).
    /// - parameter serverURL: The base/root URL for all HTTP endpoint calls. The default URL points to IG's production environment.
    /// - parameter apiKey: [API key](https://labs.ig.com/gettingstarted) given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log into an IG account.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(withDatabase databaseLocation: Database.Location, serverURL: URL = API.rootURL, apiKey: API.Key, user: API.User) -> AnyPublisher<Services,IG.Error> {
        let queue = Self._makeQueue(targetQueue: nil)
        let api = API(rootURL: serverURL, credentials: nil, targetQueue: queue, qos: queue.qos)
        return api.session.login(type: .certificate, key: apiKey, user: user)
            .flatMap { _ in Self._make(with: api, queue: queue, location: databaseLocation) }
            .eraseToAnyPublisher()
    }
    
    /// Factory method for all services, which are log into with the provided user token (whether OAuth or Certificate).
    ///
    /// The `streamer` service still requires a further `streamer.session.connect()` call.
    /// - parameter databaseLocation: The location of the database (whether "in-memory" or file system).
    /// - parameter serverURL: The base/root URL for all HTTP endpoint calls. The default URL points to IG's production environment.
    /// - parameter apiKey: [API key](https://labs.ig.com/gettingstarted) given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The API token (whether OAuth or certificate) to use to retrieve all user's data.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(withDatabase databaseLocation: Database.Location, serverURL: URL = API.rootURL, apiKey: API.Key, token: API.Token) -> AnyPublisher<Services,IG.Error> {
        let queue = Self._makeQueue(targetQueue: nil)
        let api = API(rootURL: serverURL, credentials: nil, targetQueue: queue, qos: queue.qos)
        
        /// This closure  creates  the remaining subservices from the given api key and token.
        /// - requires: The `token` passed to this closure must be valid and already tested. If not, an error event will be sent.
        let signal: (_ token: API.Token) -> Publishers.FlatMap<AnyPublisher<Services,IG.Error>,AnyPublisher<API.Session,IG.Error>> = { (token) in
            return api.session.get(key: apiKey, token: token)
                .flatMap { (session) -> AnyPublisher<Services,IG.Error> in
                    api.channel.credentials = API.Credentials(key: apiKey, client: session.client, account: session.account, streamerURL: session.streamerURL, timezone: session.timezone, token: token)
                    return Self._make(with: api, queue: queue, location: databaseLocation)
                }
        }
        
        guard token.expirationDate > Date() else {
            switch token.value {
            case .certificate:
                return Fail(error: IG.Error(.api(.invalidRequest), "The given certificate token has expired and it cannot be refreshed (it must be renewed).", help: "Log in with your username and password"))
                    .eraseToAnyPublisher()
            case .oauth(_, let refreshToken, _,_):
                return api.session.refreshOAuth(token: refreshToken, key: apiKey)
                    .mapError(errorCast)
                    .flatMap { signal($0) }
                    .eraseToAnyPublisher()
            }
        }
        
        return signal(token)
            .eraseToAnyPublisher()
    }
}

private extension Services {
    /// Creates the queue "overlord" managing all services.
    /// - parameter targetQueue: The queue were all services work items end.
    static func _makeQueue(targetQueue: DispatchQueue?) -> DispatchQueue {
        DispatchQueue(label: Bundle.IG.identifier + ".services", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: targetQueue)
    }

    /// Creates a streamer from an API instance and package both in a `Services` structure.
    /// - parameter api: The API instance with valid credentials.
    /// - parameter queue: Concurrent queue used to synchronize all IG's events.
    /// - parameter location: The location of the database (whether "in-memory" or file system).
    /// - requires: Valid (not expired) credentials on the given `API` instance or an error event will be sent.
    static func _make(with api: API, queue: DispatchQueue, location: Database.Location) -> AnyPublisher<Services,IG.Error> {
        // Check that there is API credentials.
        guard var apiCredentials = api.channel.credentials else {
            return Fail(error: IG.Error.init(.api(.invalidRequest), "No credentials were found on the API instance.", help: "Log in with your username and password."))
                .eraseToAnyPublisher()
        }
        // Check that they haven't expired.
        guard apiCredentials.token.expirationDate > Date() else {
            return Fail(error: IG.Error.init(.api(.invalidRequest), "The given credentials have expired.", help: "Log in with your username and password."))
                .eraseToAnyPublisher()
        }
        
        let subServicesGenerator: ()->Result<Services,IG.Error> = {
            do {
                let secret = try Streamer.Credentials(credentials: apiCredentials)
                let database = try Database(location: location, targetQueue: queue)
                let streamer = Streamer(rootURL: apiCredentials.streamerURL, credentials: secret, targetQueue: queue)
                return .success(Services(queue: queue, api: api, streamer: streamer, database: database))
            } catch let error {
                return .failure(error as! IG.Error)
            }
        }
        
        switch apiCredentials.token.value {
        case .oauth:
            return api.session.refreshCertificate()
                .mapError(errorCast)
                .flatMap { (token) -> Result<Services,IG.Error>.Publisher in
                    apiCredentials.token = token
                    return Result.Publisher(subServicesGenerator())
                }.eraseToAnyPublisher()
        case .certificate:
            return DeferredResult(closure: subServicesGenerator)
                .eraseToAnyPublisher()
        }
    }
}
