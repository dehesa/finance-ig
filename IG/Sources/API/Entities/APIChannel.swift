import Foundation

extension IG.API {
    /// Contains the low-level functionality related to the `URLSession` and credentials management.
    internal final class Channel {
        /// The `URLSession` instance performing the HTTPS requests.
        internal let session: URLSession
        /// The credentials used to call API endpoints.
        private var secret: IG.API.Credentials?
        /// The lock used to restrict access to the credentials.
        private let lock: UnsafeMutablePointer<os_unfair_lock>
        
        /// Designated initializer passing the basic requirements for an API channel.
        /// - parameter session: Real or mock URL session calling the endpoints.
        /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
        init(session: URLSession, credentials: IG.API.Credentials?) {
            self.session = session
            self.secret = credentials
            self.lock = UnsafeMutablePointer.allocate(capacity: 1)
            self.lock.initialize(to: os_unfair_lock())
        }
        
        deinit {
            self.session.invalidateAndCancel()
            self.lock.deallocate()
        }
        
        /// Returns the current credentials.
        internal var credentials: API.Credentials? {
            get {
                os_unfair_lock_lock(self.lock)
                let secret = self.secret
                os_unfair_lock_unlock(self.lock)
                return secret
            }
            set(newCredentials) {
                os_unfair_lock_lock(self.lock)
                self.secret = newCredentials
                os_unfair_lock_unlock(self.lock)
            }
        }
        
        /// Retrieve and modify the channel's credentials synchronously, so it cannot be modified during operation.
        ///
        /// This method is supposed to be used asynchronously. Therefore, no other calls to this channel's `credentials` properties or methods shall be called within the given closure or the program will lock.
        /// - parameter synchronizedClosure: Closure executing the priviledge instructions.
        /// - parameter credentials: The current API credentials (or `nil` if there are none).
        internal func tweakCredentials(_ synchronizedClosure: (_ credentials: IG.API.Credentials?) throws -> IG.API.Credentials?) rethrows {
            os_unfair_lock_lock(self.lock)
            defer { os_unfair_lock_unlock(self.lock) }
            self.secret = try synchronizedClosure(self.secret)
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
