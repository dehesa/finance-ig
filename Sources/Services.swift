import ReactiveSwift
import Foundation

/// High-level instance containing all services that can communicate with the IG platform.
public final class Services {
    /// Instance letting you query any API endpoint.
    public let api: API
    /// Instance letting you subscribe to lightsreamer events.
    public let streamer: Streamer
    /// Instance letting you query a databse for caching purposes.
    public let database: Database
    
    /// Designated initializer specifying every single service.
    /// - parameter api: The HTTP API manager.
    /// - parameter streamer: The Lightstreamer event manager.
    /// - parameter database: The Database manager.
    private init(api: API, streamer: Streamer, database: Database) {
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
    public static func make(serverURL: URL = API.rootURL, databaseURL: URL? = Database.rootURL, key: API.Key, user: API.User, autoconnect: Bool = true) -> SignalProducer<Services,Services.Error> {
        let api = API(rootURL: serverURL, credentials: nil)
        return api.session.login(type: .certificate, key: key, user: user)
            .mapError(Self.Error.api)
            .flatMap(.merge) { _ in Self.make(with: api, databaseURL: databaseURL, autoconnect: autoconnect) }
    }
    
    /// Factory method for all services, which are log into with the provided user token (whether OAuth or Certificate).
    /// - parameter serverURL: The base/root URL for all HTTP endpoint calls. The default URL points to IG's production environment.
    /// - parameter databaseURL: The file URL indicating the location of the caching database.
    /// - parameter key: [API key](https://labs.ig.com/gettingstarted) given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The API token (whether OAuth or certificate) to use to retrieve all user's data.
    /// - parameter autoconnect: Boolean indicating whether the `connect()` function is called on the `Streamer` instance right away, or whether it shall be called later on by the user.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(serverURL: URL = API.rootURL, databaseURL: URL? = Database.rootURL, key: API.Key, token: API.Credentials.Token, autoconnect: Bool = true) -> SignalProducer<Services,Services.Error> {
        
        let api = API(rootURL: serverURL, credentials: nil)
        
        /// This closure  creates  the othe subservices from the given api key and token.
        /// - requires: The `token` passed to this closure must be valid and already tested. If not, an error event will be sent.
        let signal: (_ token: API.Credentials.Token) -> SignalProducer<Services,Services.Error> = { (token) in
            return api.session.get(key: key, token: token)
                .mapError(Self.Error.api)
                .flatMap(.merge) { (session) -> SignalProducer<Services,Services.Error> in
                    let credentials = API.Credentials(client: session.client, account: session.account, key: key, token: token, streamerURL: session.streamerURL, timezone: session.timezone)
                    api.session.credentials = credentials
                    return Self.make(with: api, databaseURL: databaseURL, autoconnect: autoconnect)
            }
        }
        
        guard token.expirationDate > Date() else {
            switch token.value {
            case .certificate:
                let message = "The given certificate token has expired and it cannot be refreshed."
                let error: API.Error = .invalidRequest(message, suggestion: "Log in with your username and password.")
                return .init(error: .api(error: error))
            case .oauth(_, let refreshToken, _,_):
                return api.session.refreshOAuth(token: refreshToken, key: key)
                    .mapError(Self.Error.api)
                    .flatMap(.merge) { signal($0) }
            }
        }
        
        return signal(token)
    }

    /// Creates a streamer from an API instance and package both in a `Services` structure.
    /// - parameter api: The API instance with valid credentials.
    /// - parameter databaseURL: The file URL indicating the location of the caching database.
    /// - parameter autoconnect: Boolean indicating whether the `connect()` function is called on the `Streamer` instance right away, or whether it shall be called later on by the user.
    /// - requires: Valid (not expired) credentials on the given `API` instance or an error event will be sent.
    private static func make(with api: API, databaseURL: URL?, autoconnect: Bool) -> SignalProducer<Services,Services.Error> {
        // Check that there is API credentials.
        guard var apiCredentials = api.session.credentials else {
            let error: API.Error = .invalidRequest(API.Error.Message.noCredentials, suggestion: API.Error.Suggestion.logIn)
            return .init(error: .api(error: error))
        }
        // Check that they haven't expired.
        guard apiCredentials.token.expirationDate > Date() else {
            let message = "The given credentials have expired."
            let error: API.Error = .invalidRequest(message, suggestion: "Log in with your username and password.")
            return .init(error: .api(error: error))
        }
        
        let subServicesGenerator: ()->Result<Services,Services.Error> = {
            do {
                let secret = try Streamer.Credentials(credentials: apiCredentials)
                let database = try Database(rootURL: databaseURL)
                let streamer = Streamer(rootURL: apiCredentials.streamerURL, credentials: secret, autoconnect: autoconnect)
                return .success(.init(api: api, streamer: streamer, database: database))
            } catch let error as Database.Error {
                return .failure(.database(error: error))
            } catch let error as Streamer.Error {
                return .failure(.streamer(error: error))
            } catch let error as API.Error {
                return .failure(.api(error: error))
            } catch let underlyingError {
                let msg = "An unknown error appeared while creating the \(Streamer.self) and \(Database.self) instance."
                var error: Streamer.Error = .invalidRequest(msg, suggestion: Streamer.Error.Suggestion.bug)
                error.underlyingError = underlyingError
                return .failure(.streamer(error: error))
            }
        }
        
        switch apiCredentials.token.value {
        case .oauth:
            return api.session.refreshCertificate()
                .mapError(Services.Error.api)
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
    /// Wrapper for errors generated in one of the IG services.
    public enum Error: Swift.Error, CustomDebugStringConvertible {
        /// Error produced by the HTTP API subservice.
        case api(error: API.Error)
        /// Error produced by the Lightstreamer subservice.
        case streamer(error: Streamer.Error)
        /// Error produced by the Database subservice.
        case database(error: Database.Error)
        
        public var debugDescription: String {
            switch self {
            case .api(let error): return error.debugDescription
            case .streamer(let error): return error.debugDescription
            case .database(let error): return error.debugDescription
            }
        }
    }
}
