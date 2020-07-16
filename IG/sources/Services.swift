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
    public static func make(withDatabase databaseLocation: Database.Location, serverURL: URL = API.rootURL, apiKey: API.Key, user: API.User) -> AnyPublisher<Services,Services.Error> {
        let queue = Self._makeQueue(targetQueue: nil)
        let api = API(rootURL: serverURL, credentials: nil, targetQueue: queue, qos: queue.qos)
        return api.session.login(type: .certificate, key: apiKey, user: user)
            .mapError(Self.Error.api)
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
    public static func make(withDatabase databaseLocation: Database.Location, serverURL: URL = API.rootURL, apiKey: API.Key, token: API.Token) -> AnyPublisher<Services,Services.Error> {
        let queue = Self._makeQueue(targetQueue: nil)
        let api = API(rootURL: serverURL, credentials: nil, targetQueue: queue, qos: queue.qos)
        
        /// This closure  creates  the remaining subservices from the given api key and token.
        /// - requires: The `token` passed to this closure must be valid and already tested. If not, an error event will be sent.
        let signal: (_ token: API.Token) -> Publishers.FlatMap<AnyPublisher<Services,Services.Error>,Publishers.MapError<AnyPublisher<API.Session,API.Error>,Services.Error>> = { (token) in
            return api.session.get(key: apiKey, token: token)
                .mapError(Self.Error.api)
                .flatMap { (session) -> AnyPublisher<Services,Services.Error> in
                    api.channel.credentials = .init(client: session.client, account: session.account, key: apiKey, token: token, streamerURL: session.streamerURL, timezone: session.timezone)
                    return Self._make(with: api, queue: queue, location: databaseLocation)
                }
        }
        
        guard token.expirationDate > Date() else {
            switch token.value {
            case .certificate:
                return Fail(error: .api(error: .invalidRequest("The given certificate token has expired and it cannot be refreshed (it must be renewed)", suggestion: "Log in with your username and password")))
                    .eraseToAnyPublisher()
            case .oauth(_, let refreshToken, _,_):
                return api.session.refreshOAuth(token: refreshToken, key: apiKey)
                    .mapError { Self.Error.api(error: .transform($0)) }
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
    static func _make(with api: API, queue: DispatchQueue, location: Database.Location) -> AnyPublisher<Services,Services.Error> {
        // Check that there is API credentials.
        guard var apiCredentials = api.channel.credentials else {
            return Fail(error: .api(error: .invalidRequest(.noCredentials, suggestion: .logIn)))
                .eraseToAnyPublisher()
        }
        // Check that they haven't expired.
        guard apiCredentials.token.expirationDate > Date() else {
            return Fail(error: .api(error: .invalidRequest("The given credentials have expired", suggestion: "Log in with your username and password")))
                .eraseToAnyPublisher()
        }
        
        let subServicesGenerator: ()->Result<Services,Services.Error> = {
            do {
                let secret = try Streamer.Credentials(credentials: apiCredentials)
                let database = try Database(location: location, targetQueue: queue)
                let streamer = Streamer(rootURL: apiCredentials.streamerURL, credentials: secret, targetQueue: queue)
                return .success(.init(queue: queue, api: api, streamer: streamer, database: database))
            } catch let error as Database.Error {
                return .failure(.database(error: error))
            } catch let error as Streamer.Error {
                return .failure(.streamer(error: error))
            } catch let error as API.Error {
                return .failure(.api(error: error))
            } catch let underlyingError {
                var error: Streamer.Error = .invalidRequest(.init("An unknown error appeared while creating the \(Streamer.self) and \(Database.self) instance"), suggestion: .fileBug)
                error.underlyingError = underlyingError
                return .failure(.streamer(error: error))
            }
        }
        
        switch apiCredentials.token.value {
        case .oauth:
            return api.session.refreshCertificate()
                .mapError { Self.Error.api(error: API.Error.transform($0)) }
                .flatMap { (token) -> Result<Services,Services.Error>.Publisher in
                    apiCredentials.token = token
                    return .init(subServicesGenerator())
                }.eraseToAnyPublisher()
        case .certificate:
            return DeferredResult(closure: subServicesGenerator)
                .eraseToAnyPublisher()
        }
    }
}
