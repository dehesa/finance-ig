import ReactiveSwift
import Result
import Foundation

/// Wrapper around "communicators" with the platform servers.
public final class Services {
    /// Instance letting you query any API endpoint.
    public let api: API
    /// Instance letting you subscribe to events.
    public let streamer: Streamer
    
    /// Designated initializer returning all services.
    private init(api: API, streamer: Streamer) {
        self.api = api
        self.streamer = streamer
    }
    
    /// Initializes and request credentials for all platform services.
    /// - parameter rootURL: The base/root URL for all endpoint calls. The default URL hit IG's production environment.
    public static func make(rootURL: URL = URL(string: "https://api.ig.com/gateway/deal")!, info login: API.Request.Login) -> SignalProducer<Services,Services.Error> {
        let api = API(rootURL: rootURL, credentials: nil)
        
        return api.sessionLogin(login, type: .certificate)
            .mapError { Services.Error.api(error: $0) }
            .attemptMap { (credentials) -> Result<Services,Services.Error> in
                api.updateCredentials(credentials)
                
                return Result<Services,Streamer.Error> {
                    let priviledge = try credentials.streamer()
                    let streamer = Streamer(rootURL: credentials.streamerURL, credentials: priviledge)
                    return Services(api: api, streamer: streamer)
                }.mapError { Services.Error.streamer(error: $0) }
            }
    }
}

extension Services {
    /// Wrapper for errors generated in one of the IG services.
    public enum Error: Swift.Error {
        case api(error: API.Error)
        case streamer(error: Streamer.Error)
    }
}
