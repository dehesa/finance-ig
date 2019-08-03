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
    
    /// Initializes and request credentials for all platform services.
    /// - parameter rootURL: The base/root URL for all HTTP endpoint calls. The default URL hit IG's production environment.
    /// - parameter apiKey: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log in into an IG account.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(rootURL: URL = API.rootURL, apiKey: String, user: API.User) -> SignalProducer<Services,Services.Error> {
        let api = API(rootURL: rootURL, credentials: nil)
        return api.session.login(type: .certificate, apiKey: apiKey, user: user)
            .mapError(Self.Error.api)
            .flatMap(.merge) { Self.make(with: api) }
    }
    
    /// Initializes and request credentials for all platform services with the given API token.
    /// - parameter rootURL: The base/root URL for all HTTP endpoint calls. The default URL hit IG's production environment.
    /// - parameter token: The API token (whether OAuth or certificate) to use to retrieve all user's data.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    /// - todo: Even OAuth can access certificate credentials. Implement it here at some point.
    public static func make(rootURL: URL = API.rootURL, apiKey: String, token: API.Credentials.Token) -> SignalProducer<Services,Services.Error> {
        let api = API(rootURL: rootURL, credentials: nil)
        // Signal producing the services with a valid apiKey and already tested token.
        let signal: (_ apiKey: String, _ token: API.Credentials.Token) -> SignalProducer<Services,Services.Error> = { (apiKey, token) in
            return api.session.get(apiKey: apiKey, token: token)
                .mapError(Self.Error.api)
                .flatMap(.merge) { (session) -> SignalProducer<Services,Services.Error> in
                    let credentials = API.Credentials(clientId: session.clientIdentifier, accountId: session.accountIdentifier, apiKey: apiKey, token: token, streamerURL: session.streamerURL, timezone: session.timezone)
                    api.session.credentials = credentials
                    return Self.make(with: api)
            }
        }
        
        guard token.expirationDate > Date() else {
            switch token.value {
            case .certificate:
                return .init(error: .api(error: .invalidCredentials(nil, message: "The given certificate token has expired and it cannot be refreshed. Please log in with your username and password.")))
            case .oauth(_, let refreshToken, _,_):
                return api.session.refreshOAuth(token: refreshToken, apiKey: apiKey)
                    .mapError(Self.Error.api)
                    .flatMap(.merge) { signal(apiKey, $0) }
            }
        }
        
        return signal(apiKey, token)
    }

    /// It creates a streamer from an API.
    /// - parameter api: The API instance is expected to have credentials set in. If not, this function will return an error on the producer.
    private static func make(with api: API) -> SignalProducer<Services,Services.Error> {
        // Check that there is API credentials.
        guard let apiCredentials = api.session.credentials else {
            return .init(error: .api(error: .invalidCredentials(nil, message: "No API credentials were found.")))
        }
        // Check that they haven't expired.
        guard apiCredentials.token.expirationDate > Date() else {
            return .init(error: .api(error: .invalidCredentials(apiCredentials, message: "The API credentials have expired.")))
        }
        
        switch apiCredentials.token.value {
        case .oauth:
            return api.session.refreshCertificate()
                .mapError(Services.Error.api)
                .map {
                    guard case .certificate(let access, let security) = $0.value else { fatalError("The token was not of certificate type.") }
                    guard let password = Streamer.Credentials.password(fromCST: access, security: security) else { fatalError("The CST and/or security tokens were empty.") }
                    let secret = Streamer.Credentials(identifier: apiCredentials.accountIdentifier, password: password)
                    let streamer = Streamer(rootURL: apiCredentials.streamerURL, credentials: secret)
                    return .init(api: api, streamer: streamer)
                }
        case .certificate:
            return .init { () -> Result<Services,Services.Error> in
                let secret: Streamer.Credentials
                do {
                    secret = try apiCredentials.streamerCredentials()
                } catch let error as API.Error {
                    return .failure(.api(error: error))
                } catch let error as Streamer.Error {
                    return .failure(.streamer(error: error))
                } catch let error {
                    let invalid: Streamer.Error = .invalidCredentials(nil, message: "An unknown error appeared while creating the streamer credentials. Error: \(error)")
                    return .failure(.streamer(error: invalid))
                }
                
                let streamer = Streamer(rootURL: apiCredentials.streamerURL, credentials: secret)
                return .success(.init(api: api, streamer: streamer))
            }
        }
    }
}

extension Services {
    /// Wrapper for errors generated in one of the IG services.
    public enum Error: Swift.Error {
        /// Error produced by the HTTP API subservice.
        case api(error: API.Error)
        /// Error produced by the Lightstreamer subservice.
        case streamer(error: Streamer.Error)
    }
}
