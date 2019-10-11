import Combine
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
    ///
    /// The `streamer` service still requires a further `streamer.session.connect()` call.
    /// - parameter serverURL: The base/root URL for all HTTP endpoint calls. The default URL points to IG's production environment.
    /// - parameter databaseURL: The file URL indicating the location of the caching database.
    /// - parameter key: [API key](https://labs.ig.com/gettingstarted) given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log into an IG account.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(serverURL: URL = IG.API.rootURL, databaseURL: URL? = IG.DB.rootURL, key: IG.API.Key, user: IG.API.User) -> IG.Services.DiscretePublisher<IG.Services> {
        let queue = Self.makeQueue(targetQueue: nil)
        let api = IG.API(rootURL: serverURL, credentials: nil, targetQueue: queue)
        return api.session.login(type: .certificate, key: key, user: user)
            .mapError(Self.Error.api)
            .flatMap { _ in Self.make(with: api, queue: queue, databaseURL: databaseURL) }
            .eraseToAnyPublisher()
    }
    
    /// Factory method for all services, which are log into with the provided user token (whether OAuth or Certificate).
    ///
    /// The `streamer` service still requires a further `streamer.session.connect()` call.
    /// - parameter serverURL: The base/root URL for all HTTP endpoint calls. The default URL points to IG's production environment.
    /// - parameter databaseURL: The file URL indicating the location of the caching database.
    /// - parameter key: [API key](https://labs.ig.com/gettingstarted) given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The API token (whether OAuth or certificate) to use to retrieve all user's data.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(serverURL: URL = IG.API.rootURL, databaseURL: URL? = IG.DB.rootURL, key: IG.API.Key, token: IG.API.Credentials.Token) -> IG.Services.DiscretePublisher<IG.Services> {
        let queue = Self.makeQueue(targetQueue: nil)
        let api = IG.API(rootURL: serverURL, credentials: nil, targetQueue: queue)
        
        /// This closure  creates  the remaining subservices from the given api key and token.
        /// - requires: The `token` passed to this closure must be valid and already tested. If not, an error event will be sent.
        let signal: (_ token: IG.API.Credentials.Token) -> Publishers.FlatMap<IG.Services.DiscretePublisher<Services>,Publishers.MapError<IG.API.DiscretePublisher<IG.API.Session>,IG.Services.Error>> = { (token) in
            return api.session.get(key: key, token: token)
                .mapError(Self.Error.api)
                .flatMap { (session) -> IG.Services.DiscretePublisher<IG.Services> in
                    api.channel.credentials = .init(client: session.client, account: session.account, key: key, token: token, streamerURL: session.streamerURL, timezone: session.timezone)
                    return Self.make(with: api, queue: queue, databaseURL: databaseURL)
                }
        }
        
        guard token.expirationDate > Date() else {
            switch token.value {
            case .certificate:
                return Fail(error: .api(error: .invalidRequest("The given certificate token has expired and it cannot be refreshed (it must be renewed)", suggestion: "Log in with your username and password")))
                    .eraseToAnyPublisher()
            case .oauth(_, let refreshToken, _,_):
                return api.session.refreshOAuth(token: refreshToken, key: key)
                    .mapError { Self.Error.api(error: .transform($0)) }
                    .flatMap { signal($0) }
                    .eraseToAnyPublisher()
            }
        }
        
        return signal(token)
            .eraseToAnyPublisher()
    }
    
    /// Creates the queue "overlord" managing all services.
    /// - parameter targetQueue: The queue were all services work items end.
    private static func makeQueue(targetQueue: DispatchQueue?) -> DispatchQueue {
        return DispatchQueue(label: Self.reverseDNS, qos: .utility, attributes: .concurrent, autoreleaseFrequency: .never, target: targetQueue)
    }

    /// Creates a streamer from an API instance and package both in a `Services` structure.
    /// - parameter api: The API instance with valid credentials.
    /// - parameter databaseURL: The file URL indicating the location of the caching database.
    /// - requires: Valid (not expired) credentials on the given `API` instance or an error event will be sent.
    private static func make(with api: IG.API, queue: DispatchQueue, databaseURL: URL?) -> IG.Services.DiscretePublisher<IG.Services> {
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
        
        let subServicesGenerator: ()->Result<IG.Services,IG.Services.Error> = {
            do {
                let secret = try IG.Streamer.Credentials(credentials: apiCredentials)
                let database = try DB(rootURL: databaseURL, targetQueue: queue)
                let streamer = IG.Streamer(rootURL: apiCredentials.streamerURL, credentials: secret, targetQueue: queue)
                return .success(.init(queue: queue, api: api, streamer: streamer, database: database))
            } catch let error as IG.DB.Error {
                return .failure(.database(error: error))
            } catch let error as IG.Streamer.Error {
                return .failure(.streamer(error: error))
            } catch let error as IG.API.Error {
                return .failure(.api(error: error))
            } catch let underlyingError {
                var error: IG.Streamer.Error = .invalidRequest(.init("An unknown error appeared while creating the \(IG.Streamer.self) and \(IG.DB.self) instance"), suggestion: .fileBug)
                error.underlyingError = underlyingError
                return .failure(.streamer(error: error))
            }
        }
        
        switch apiCredentials.token.value {
        case .oauth:
            return api.session.refreshCertificate()
                .mapError { Self.Error.api(error: IG.API.Error.transform($0)) }
                .flatMap { (token) -> Result<IG.Services,IG.Services.Error>.Publisher in
                    apiCredentials.token = token
                    return .init(subServicesGenerator())
                }.eraseToAnyPublisher()
        case .certificate:
            return DeferredResult(closure: subServicesGenerator)
                .eraseToAnyPublisher()
        }
    }
}

extension Services {
    /// Type erased `Combine.Future` where a single value and a completion or a failure will be sent.
    /// This behavior is guaranteed when you see this type.
    public typealias DiscretePublisher<T> = Combine.AnyPublisher<T,IG.Services.Error>
    /// Publisher that can send zero, one, or many values followed by a successful completion.
    ///
    /// This type is typically semantically used for paginated requests.
    public typealias ContinuousPublisher<T> = Combine.AnyPublisher<T,IG.Services.Error>
    
    /// The reverse DNS identifier for the `API` instance.
    internal static var reverseDNS: String {
        return IG.Bundle.identifier + ".services"
    }
}

extension Services: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.Bundle.name).\(Self.self)"
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
