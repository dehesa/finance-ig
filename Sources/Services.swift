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
    /// - parameter loginInfo: The login information to enable the HTTP and Lightstreamer interfaces.
    /// - returns: A fully initialized `Services` instance with all services enabled (and logged in).
    public static func make(rootURL: URL = API.rootURL, loginInfo: API.Request.Login) -> SignalProducer<Services,Services.Error> {
        let api = API(rootURL: rootURL, credentials: nil)
        
        return api.sessionLogin(loginInfo, type: .certificate)
            .mapError(Services.Error.api)
            .attemptMap { (credentials) -> Result<Services,Services.Error> in
                api.updateCredentials(credentials)
                
                let priviledge: Streamer.Credentials
                do {
                    priviledge = try credentials.streamer()
                } catch let error {
                    return .failure(.streamer(error: error as! Streamer.Error))
                }
                
                let streamer = Streamer(rootURL: credentials.streamerURL, credentials: priviledge)
                return .success(.init(api: api, streamer: streamer))
            }
    }
    
    //#warning("TODO: Create a make function accepting tokens instead of passwords")
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
