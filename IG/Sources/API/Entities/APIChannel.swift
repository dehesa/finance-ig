import Combine
import Foundation

extension IG.API {
    /// Contains the low-level functionality related to the `URLSession` and credentials management.
    internal final class Channel {
        /// The `URLSession` instance performing the HTTPS requests.
        internal let session: URLSession
        /// The credentials used to call API endpoints.
        private var _secret: IG.API.Credentials?
        /// A subject subscribing to the API credentials status (it doesn't send duplicates).
        private let _statusSubject: CurrentValueSubject<IG.API.Session.Status,Never>
        /// The processing queue for the status cancellable.
        private var _statusScheduler: DispatchQueue
        /// The cancellable for the expiration timer.
        private var _statusTimer: DispatchWorkItem?
        /// The lock used to restrict access to the credentials.
        private let _lock: UnsafeMutablePointer<os_unfair_lock>
        
        /// Designated initializer passing the basic requirements for an API channel.
        /// - parameter session: Real or mock URL session calling the endpoints.
        /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
        internal init(session: URLSession, credentials: IG.API.Credentials?, queue: DispatchQueue) {
            self.session = session
            self._secret = nil
            self._statusSubject = .init(.logout)
            self._statusScheduler = queue
            self._statusTimer = nil
            self._lock = UnsafeMutablePointer.allocate(capacity: 1)
            self._lock.initialize(to: os_unfair_lock())
            
            guard let creds = credentials else { return }
            self.credentials = creds
        }
        
        deinit {
            os_unfair_lock_lock(self._lock)
            self._statusTimer?.cancel()
            self._statusTimer = nil
            self._secret = nil
            os_unfair_lock_unlock(self._lock)
            self.session.invalidateAndCancel()
            self._lock.deinitialize(count: 1)
            self._lock.deallocate()
        }
        
        /// Returns the current credentials.
        ///
        /// If credentials are set and they are different than previous ones, a status event will be published with its appropriate case.
        internal var credentials: API.Credentials? {
            get {
                os_unfair_lock_lock(self._lock)
                let secret = self._secret
                os_unfair_lock_unlock(self._lock)
                return secret
            }
            set { self.tweakCredentials { (_) in newValue } }
        }
        
        /// Retrieve and modify the channel's credentials synchronously, so it cannot be modified during operation.
        ///
        /// This method is supposed to be used asynchronously. Therefore, no other calls to this channel's `credentials` properties or methods shall be called within the given closure or the program will lock.
        /// - parameter synchronizedClosure: Closure executing the priviledge instructions.
        /// - parameter credentials: The current API credentials (or `nil` if there are none).
        internal func tweakCredentials(_ synchronizedClosure: (_ credentials: IG.API.Credentials?) throws -> IG.API.Credentials?) rethrows {
            os_unfair_lock_lock(self._lock)
            let newCredentials: API.Credentials?
            do {
                newCredentials = try synchronizedClosure(self._secret)
            } catch let error {
                os_unfair_lock_unlock(self._lock)
                throw error
            }
            
            let previousDate = self._secret?.token.expirationDate
            let currentDate = newCredentials?.token.expirationDate
            self._secret = newCredentials
            // If the expiration date is exactly the same as the one stored, there is no need to send any status event.
            guard previousDate != currentDate else {
                return os_unfair_lock_unlock(self._lock)
            }
            
            self._statusTimer?.cancel()
            self._statusTimer = nil
            
            // If there are no credentials and before there were some (whether "ready" or "expired"), send a "logout" event.
            guard let currentExpirationDate = currentDate else {
                os_unfair_lock_unlock(self._lock)
                return self._statusSubject.send(.logout)
            }
            
            let limitDate = Date(timeIntervalSinceNow: 0.1)
            // If the new expiration date is less than aproximately now. Set the "expired" status
            guard currentExpirationDate > limitDate else {
                os_unfair_lock_unlock(self._lock)
                if let previousExpirationDate = previousDate, previousExpirationDate <= limitDate { return }
                return self._statusSubject.send(.expired)
            }
            // If the code reaches here, the new expiration date is a valid date in the future
            let indicator = DispatchWorkItem { [weak self] in
                self?._statusTimer = nil
                self?._statusSubject.send(.expired)
            }
            self._statusTimer = indicator
            
            let deadline = currentExpirationDate.timeIntervalSince(Date(timeIntervalSinceNow: -0.05))
            os_unfair_lock_unlock(self._lock)
            
            self._statusSubject.send(.ready(till: currentExpirationDate))
            self._statusScheduler.asyncAfter(deadline: .now() + deadline, execute: indicator)
        }
        
        /// The current status for the API credentials.
        var status: IG.API.Session.Status {
            self._statusSubject.value
        }
        
        /// Subscribes to the credentials status (i.e. whether they are expired, etc.).
        /// - remark: This publisher filter out any status duplication; therefore each event is unique.
        /// - parameter queue: `DispatchQueue` were values are received.
        internal func subscribeToStatus(on queue: DispatchQueue? = nil) -> Publishers.ReceiveOn<CurrentValueSubject<API.Session.Status,Never>,DispatchQueue> {
            self._statusSubject.receive(on: queue ?? self._statusScheduler)
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
