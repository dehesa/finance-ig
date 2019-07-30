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
            .mapError(Services.Error.api)
            .attemptMap { (_) -> Result<Services,Services.Error> in
                guard let credentials = api.session.credentials else {
                    return .failure(.api(error: .invalidCredentials(nil, message: "No credentials were found.")))
                }
                
                let secret: Streamer.Credentials
                do {
                    secret = try credentials.streamer()
                } catch let error {
                    return .failure(.streamer(error: error as! Streamer.Error))
                }
                
                let streamer = Streamer(rootURL: credentials.streamerURL, credentials: secret)
                return .success(.init(api: api, streamer: streamer))
            }
    }
    
    /// Initializes and request credentials for all platform services with the given API token.
    /// - attention: Only API tokens of type `.certificate` are allowed here.
    /// - parameter rootURL: The base/root URL for all HTTP endpoint calls. The default URL hit IG's production environment.
    /// - parameter token: The API token (whether OAuth or certificate) to use to retrieve all user's data.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    /// - todo: Even OAuth can access certificate credentials. Implement it here at some point.
    public static func make(rootURL: URL = API.rootURL, apiKey: String, token: API.Credentials.Token) -> SignalProducer<Services,Services.Error> {
        guard case .certificate = token.value else {
            return SignalProducer(error: .api(error: .invalidCredentials(nil, message: "Only certificate credentials are allowed to create a streamer instance")))
        }
        
        let api = API(rootURL: rootURL, credentials: nil)

        return api.session.get(apiKey: apiKey, token: token)
            .mapError(Services.Error.api)
            .attemptMap { (session) -> Result<Services,Services.Error> in
                let credentials = API.Credentials(clientId: session.clientId, accountId: session.accountId, apiKey: apiKey, token: token, streamerURL: session.streamerURL, timezone: session.timezone)
                api.session.credentials = credentials
                
                let secret: Streamer.Credentials
                do {
                    secret = try credentials.streamer()
                } catch let error {
                    return .failure(.streamer(error: error as! Streamer.Error))
                }
                
                let streamer = Streamer(rootURL: credentials.streamerURL, credentials: secret)
                return .success(.init(api: api, streamer: streamer))
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
