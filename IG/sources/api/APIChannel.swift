import Combine
import Foundation

extension API {
    /// Contains the low-level functionality related to the `URLSession` and credentials management.
    internal final class Channel {
        /// The `URLSession` instance performing the HTTPS requests.
        internal let session: URLSession
        
        /// The lock used to restrict access to the credentials.
        private let _lock: UnfairLock
        /// The credentials used to call API endpoints.
        private var _credentials: API.Credentials?
        /// The processing queue for the status cancellable.
        private let _scheduler: DispatchQueue
        
        /// The current session status.
        private var _status: API.Session.Status
        /// A subject subscribing to the API credentials status (it doesn't send duplicates).
        /// - remark: The subject never fails and only completes successfully when the `Channel` gets deinitialized.
        private let _statusSubject: PassthroughSubject<API.Session.Status,Never>
        /// The status scheduler announcing when a token has expired.
        private var _statusTimer: DispatchSourceTimer?
        
        /// Designated initializer passing the basic requirements for an API channel.
        /// - parameter session: Real or mock URL session calling the endpoints.
        /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
        /// - parameter scheduler: Queue used to schedule status changes (e.g. from valid token to expired).
        internal init(session: URLSession, credentials: API.Credentials?, scheduler: DispatchQueue) {
            self.session = session
            self._credentials = nil
            self._lock = UnfairLock()
            self._scheduler = scheduler
            self._status = .logout
            self._statusSubject = .init()
            self._statusTimer = nil
            // Set the expiration timer if necessary.
            if let creds = credentials {
                self.setCredentials(synchronizing: { _ in creds })
            }
        }
        
        deinit {
            self._lock.execute { self._destroyTimer() }
            self.session.invalidateAndCancel()
            self._statusSubject.send(completion: .finished)
            self._lock.invalidate()
        }
        
        /// Returns the current credentials.
        ///
        /// If credentials are set and they are different than previous ones, a status event will be published with its appropriate case.
        internal var credentials: API.Credentials? {
            get { self._lock.execute(within: { self._credentials }) }
            set { self.setCredentials(synchronizing: { (_) in newValue }) }
        }
        
        /// The current status for the API credentials.
        var status: API.Session.Status {
            return self._lock.execute { self._status }
        }
        
        /// Subscribes to the credentials status (i.e. whether they are expired, etc.).
        /// - remark: The subject never fails and only completes successfully when the `Channel` gets deinitialized.
        /// - parameter queue: `DispatchQueue` were values are received.
        /// - returns: Publisher emitting unique status values.
        internal func statusStream(on queue: DispatchQueue) -> Publishers.ReceiveOn<PassthroughSubject<API.Session.Status,Never>,DispatchQueue> {
            self._statusSubject.receive(on: queue)
        }
    }
}

extension API.Channel {
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
    
    /// Retrieve and modify the channel's credentials.
    /// - parameter closure: The closure provides the current credentials as they are at the time of closure execution, and returns the new credentials (or throw an error, in which cases the credentials are not modified).
    /// - parameter credentials: The current API credentials (or `nil` if there are none).
    internal func setCredentials(synchronizing closure: (_ credentials: API.Credentials?) throws -> API.Credentials?) rethrows {
        // 1. Execute the closure within a lock.
        self._lock.lock()
        let newCredentials: API.Credentials?
        do {
            newCredentials = try closure(self._credentials)
        } catch let error {
            // 1.1. If there was an error in the closure, just rethrow the error and don't do any changes.
            self._lock.unlock()
            throw error
        }
        
        let previousDate = self._credentials?.token.expirationDate
        let currentDate = newCredentials?.token.expirationDate
        // 2. Store the new credentials.
        self._credentials = newCredentials
        // 3. If the expiration date is exactly the same as the one stored, there is no need to modify any timer.
        guard previousDate != currentDate else { return self._lock.unlock() }
        // 4. Invalidate previous expiration timers (if any).
        self._destroyTimer()
        // 5. If there are no credentials and before there were some (whether "ready" or "expired"), send a "logout" event.
        guard let currentExpirationDate = currentDate else {
            self._status = .logout
            self._lock.unlock()
            return self._statusSubject.send(.logout)
        }
        // 6. If the new expiration date is further in the past than (aproximately) now. Set the "expired" status
        guard currentExpirationDate > Date(timeIntervalSinceNow: 0.1) else {
            if case .expired = self._status { return self._lock.unlock() }
            self._status = .expired
            self._lock.unlock()
            return self._statusSubject.send(.expired)
        }
        // 7. If the code reaches this point, the new expiration date is a valid date in the future
        let deadline = currentExpirationDate.timeIntervalSince(Date(timeIntervalSinceNow: -0.05))
        self._status = .ready(till: currentExpirationDate)
        self._scheduleTimer(deadline: .now() + deadline)
        self._lock.unlock()
        self._statusSubject.send(.ready(till: currentExpirationDate))
    }
}

private extension API.Channel {
    /// Creates and schedules a timer for token/credentials expiration.
    /// - attention: This function mst be called within a lock.
    func _scheduleTimer(deadline: DispatchTime) {
        assert(self._statusTimer == nil)
        
        let source = DispatchSource.makeTimerSource(queue: self._scheduler)
        source.setEventHandler { [unowned self] in
            guard self._lock.execute(within: { () -> Bool in
                // 1. Deallocate the timer.
                self._statusTimer = nil
                // 2. Set the status to expired (if necessary; never duplicate events).
                if case .expired = self._status { return false }
                self._status = .expired
                return true
            }) else { return }
            // 3. If the status needs to be emitted, do it.
            self._statusSubject.send(.expired)
        }
        
        self._statusTimer = source
        source.schedule(deadline: deadline, repeating: .never, leeway: .nanoseconds(10))
        source.activate()
    }
    
    /// Cancels and delocates the ongoing timer (if any).
    /// - attention: This function mst be called within a lock.
    func _destroyTimer() {
        guard let source = self._statusTimer else { return }
        source.cancel()
        self._statusTimer = nil
    }
}
