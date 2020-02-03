import Combine
import Foundation

extension IG.API {
    /// Contains the low-level functionality related to the `URLSession` and credentials management.
    internal final class Channel {
        /// The `URLSession` instance performing the HTTPS requests.
        internal let session: URLSession
        /// The credentials used to call API endpoints.
        private var secret: IG.API.Credentials?
        /// A subject subscribing to the API credentials status.
        private let statusSubject: PassthroughSubject<IG.API.Session.Status,Never>
        /// The processing queue for the status cancellable.
        private var statusScheduler: DispatchQueue
        /// The cancellable for the expiration timer.
        private var statusIndicator: DispatchWorkItem?
        /// The lock used to restrict access to the credentials.
        private let lock: UnsafeMutablePointer<os_unfair_lock>
        
        /// Designated initializer passing the basic requirements for an API channel.
        /// - parameter session: Real or mock URL session calling the endpoints.
        /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
        init(session: URLSession, credentials: IG.API.Credentials?, queue: DispatchQueue) {
            self.session = session
            self.secret = nil
            self.statusSubject = .init()
            self.statusScheduler = queue
            self.statusIndicator = nil
            self.lock = UnsafeMutablePointer.allocate(capacity: 1)
            self.lock.initialize(to: os_unfair_lock())
            
            guard let creds = credentials else { return }
            self.credentials = creds
        }
        
        deinit {
            os_unfair_lock_lock(self.lock)
            self.statusIndicator?.cancel()
            self.statusIndicator = nil
            self.secret = nil
            os_unfair_lock_unlock(self.lock)
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
                let previousDate = self.secret?.token.expirationDate
                let currentDate = newCredentials?.token.expirationDate
                self.secret = newCredentials
                // If the expiration date is exactly the same as the one stored, don't perform any work.
                guard previousDate != currentDate else {
                    return os_unfair_lock_unlock(self.lock)
                }
                self.statusIndicator?.cancel()
                self.statusIndicator = nil
                // If there is no credentials, send a "logout" event.
                guard let currentExpirationDate = currentDate else {
                    os_unfair_lock_unlock(self.lock)
                    return self.statusSubject.send(.logout)
                }
                let limitDate = Date(timeIntervalSinceNow: 0.1)
                // If the new expiration date is less than aproximately now. Set the "expired" status
                guard currentExpirationDate > limitDate else {
                    os_unfair_lock_unlock(self.lock)
                    if let previousExpirationDate = previousDate, previousExpirationDate <= limitDate { return }
                    return self.statusSubject.send(.expired)
                }
                // If the code reaches here, the new expiration date is a valid date in the future
                let indicator = DispatchWorkItem { [weak self] in
                    self?.statusIndicator = nil
                    self?.statusSubject.send(.expired)
                }
                self.statusIndicator = indicator
                
                let deadline = currentExpirationDate.timeIntervalSince(Date(timeIntervalSinceNow: -0.05))
                os_unfair_lock_unlock(self.lock)
                
                self.statusSubject.send(.ready(till: currentExpirationDate))
                self.statusScheduler.asyncAfter(deadline: .now() + deadline, execute: indicator)
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
        
        /// The current status for the API credentials.
        var status: IG.API.Session.Status {
            os_unfair_lock_lock(self.lock)
            defer { os_unfair_lock_unlock(self.lock) }
            
            switch self.secret?.token.expirationDate {
            case .none: return .logout
            case let date? where date <= Date(timeIntervalSinceNow: 0.1): return .expired
            case let date?: return .ready(till: date)
            }
        }
        
        /// Subscribes to the credentials status (i.e. whether they are expired, etc.).
        /// - parameter queue: `DispatchQueue` were values are received.
        internal func subscribeToStatus(on queue: DispatchQueue? = nil) -> AnyPublisher<IG.API.Session.Status,Never> {
            self.statusSubject.receive(on: queue ?? self.statusScheduler).eraseToAnyPublisher()
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
