import Foundation

extension IG.API {
    /// Contains the low-level functionality related to the `URLSession` and credentials management.
    internal final class Channel {
        /// The queue handling the accesses to credentials.
        private let queue: DispatchQueue
        /// The `URLSession` instance performing the HTTPS requests.
        internal let session: URLSession
        /// The credentials used to call API endpoints.
        private var secret: IG.API.Credentials?
        
        init(session: URLSession, queue: DispatchQueue, credentials: IG.API.Credentials?) {
            self.session = session
            self.queue = queue
            self.secret = credentials
        }
        
        deinit {
            self.session.invalidateAndCancel()
        }
        
        /// Returns the current credentials.
        internal var credentials: API.Credentials? {
            get {
                self.queue.sync { self.secret }
            }
            set(newCredentials) {
                self.queue.sync { self.secret = newCredentials }
            }
        }
        
        /// Retrieve and modify the channel's credentials synchronously, so it cannot be modified during operation.
        /// - parameter synchronizedClosure: Closure executing the priviledge instructions.
        /// - note: No other channel's `credentials` properties or methods shall be called within the given closure or the program will lock.
        internal func tweakCredentials(_ synchronizedClosure: (_ credentials: IG.API.Credentials?) throws -> IG.API.Credentials?) rethrows {
            try self.queue.sync {
                self.secret = try synchronizedClosure(self.secret)
            }
        }
    }
}

extension IG.API.Channel {
    /// Default configuration for the underlying URLSession
    internal static var defaultSessionConfigurations: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.networkServiceType = .default
        configuration.allowsCellularAccess = true
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpShouldUsePipelining = true
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return configuration
    }
}
