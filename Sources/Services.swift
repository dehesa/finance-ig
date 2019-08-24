import ReactiveSwift
import Foundation

/// High-level instance containing all services that can communicate with the IG platform.
public final class Services {
    /// Instance letting you query any API endpoint.
    public let api: API
    /// Instance letting you subscribe to lightsreamer events.
    public let streamer: Streamer
    
    /// Designated initializer specifying every single service.
    /// - parameter api: The HTTP API manager.
    /// - parameter streamer: The Lightstreamer event manager.
    private init(api: API, streamer: Streamer) {
        self.api = api
        self.streamer = streamer
    }
    
    /// Factory method for all services, which are log into with the provided user credentials.
    /// - parameter rootURL: The base/root URL for all HTTP endpoint calls. The default URL points to IG's production environment.
    /// - parameter key: [API key](https://labs.ig.com/gettingstarted) given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log into an IG account.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(rootURL: URL = API.rootURL, key: API.Key, user: API.User) -> SignalProducer<Services,Services.Error> {
        let api = API(rootURL: rootURL, credentials: nil)
        return api.session.login(type: .certificate, key: key, user: user)
            .mapError(Self.Error.api)
            .flatMap(.merge) { _ in Self.make(with: api) }
    }
    
    /// Factory method for all services, which are log into with the provided user token (whether OAuth or Certificate).
    /// - parameter rootURL: The base/root URL for all HTTP endpoint calls. The default URL points to IG's production environment.
    /// - parameter key: [API key](https://labs.ig.com/gettingstarted) given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The API token (whether OAuth or certificate) to use to retrieve all user's data.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(rootURL: URL = API.rootURL, key: API.Key, token: API.Credentials.Token) -> SignalProducer<Services,Services.Error> {
        let api = API(rootURL: rootURL, credentials: nil)
        /// Signal generating the `Streamer` service from the given api key and token.
        /// - requires: The `token` passed to this closure must be valid and already tested. If not, an error event will be sent.
        let signal: (_ key: API.Key, _ token: API.Credentials.Token) -> SignalProducer<Services,Services.Error> = { (key, token) in
            return api.session.get(key: key, token: token)
                .mapError(Self.Error.api)
                .flatMap(.merge) { (session) -> SignalProducer<Services,Services.Error> in
                    let credentials = API.Credentials(client: session.client, account: session.account, key: key, token: token, streamerURL: session.streamerURL, timezone: session.timezone)
                    api.session.credentials = credentials
                    return Self.make(with: api)
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
                    .flatMap(.merge) { signal(key, $0) }
            }
        }
        
        return signal(key, token)
    }

    /// Creates a streamer from an API instance and package both in a `Services` structure.
    /// - parameter api: The API instance with valid credentials.
    /// - requires: Valid (not expired) credentials on the given `API` instance or an error event will be sent.
    private static func make(with api: API) -> SignalProducer<Services,Services.Error> {
        // Check that there is API credentials.
        guard let apiCredentials = api.session.credentials else {
            let error: API.Error = .invalidRequest(API.Error.Message.noCredentials, suggestion: API.Error.Suggestion.logIn)
            return .init(error: .api(error: error))
        }
        // Check that they haven't expired.
        guard apiCredentials.token.expirationDate > Date() else {
            let message = "The given credentials have expired."
            let error: API.Error = .invalidRequest(message, suggestion: "Log in with your username and password.")
            return .init(error: .api(error: error))
        }
        
        switch apiCredentials.token.value {
        case .oauth:
            return api.session.refreshCertificate()
                .mapError(Services.Error.api)
                .attemptMap {
                    guard case .certificate(let access, let security) = $0.value else {
                        let error = API.Error(.invalidResponse, "The token received was not of certificate type.", suggestion: API.Error.Suggestion.bug)
                        return .failure(.api(error: error))
                    }
                    guard let password = Streamer.Credentials.password(fromCST: access, security: security) else {
                        let error = API.Error(.invalidResponse, "The certificate tokens (CST and/or security) were empty.", suggestion: API.Error.Suggestion.bug)
                        return .failure(.api(error: error))
                    }
                    let secret = Streamer.Credentials(identifier: apiCredentials.account, password: password)
                    let streamer = Streamer(rootURL: apiCredentials.streamerURL, credentials: secret)
                    return .success(.init(api: api, streamer: streamer))
                }
        case .certificate:
            return .init { () -> Result<Services,Services.Error> in
                let secret: Streamer.Credentials
                do {
                    secret = try .init(credentials: apiCredentials)
                } catch let error as Streamer.Error {
                    return .failure(.streamer(error: error))
                } catch let error as API.Error {
                    return .failure(.api(error: error))
                } catch let underlyingError {
                    var error: Streamer.Error = .invalidRequest("An unknown error appeared while creating the streamer credentials.", suggestion: Streamer.Error.Suggestion.bug)
                    error.underlyingError = underlyingError
                    return .failure(.streamer(error: error))
                }
                
                let streamer = Streamer(rootURL: apiCredentials.streamerURL, credentials: secret)
                return .success(.init(api: api, streamer: streamer))
            }
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
        
        public var debugDescription: String {
            switch self {
            case .api(let error): return error.debugDescription
            case .streamer(let error): return error.debugDescription
            }
        }
    }
}
