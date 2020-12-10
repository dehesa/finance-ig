#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#elseif os(tvOS)
import Lightstreamer_tvOS_Client
#else
#error("OS currently not supported")
#endif
import Conbini
import Combine
import Foundation

extension Streamer {
    /// Instances of this class control the underlying LIghtStreamer objects.
    internal final class Channel: NSObject {
        /// The low-level lightstreamer client actually performing the network calls.
        /// - seealso: https://www.lightstreamer.com/repo/cocoapods/ls-ios-client/api-ref/2.1.2/classes.html
        @nonobjc private let _client: LSLightstreamerClient
        
        /// The lock used to restrict access to the credentials.
        @nonobjc private let _lock: UnfairLock
        /// Streamer credentials used to access the trading platform.
        @nonobjc let credentials: Streamer.Credentials
        
        /// The current session status.
        @nonobjc private var _status: Streamer.Session.Status
        /// A subject subscribing to the session status.
        /// - remark: The subject never fails and only completes successfully when the `Channel` gets deinitialized.
        @nonobjc private let _statusSubject: PassthroughSubject<Streamer.Session.Status,Never>
        /// Sends a `()` everytime a unsubscription is requested.
        /// - remark: The subject never completes (when `Channel` gets deinitialized, the subject gets cancelled).
        @nonobjc private let _unsubscriptionSubject: PassthroughSubject<(),Never>
        
        /// Initializes the session setting up all parameters to be ready to connect.
        /// - parameter rootURL: The URL where the streaming server is located.
        /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
        @nonobjc init(rootURL: URL, credentials: Streamer.Credentials) {
            // 1. Remove the usage of ObjC exceptions by the Lightstreamer framework.
            if !LSLightstreamerClient.limitExceptionsUse { LSLightstreamerClient.limitExceptionsUse = true }
            // 2. Set up the lightstreamer client with the root URL, user, and password.
            self._client = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil)
            self._client.connectionDetails.user = credentials.identifier.description
            self._client.connectionDetails.setPassword(credentials.password)
            // 3. Set up all the remaining variables managing the Lighstreamer state.
            self._lock = UnfairLock()
            self.credentials = credentials
            self._status = .disconnected(isRetrying: false)
            self._statusSubject = PassthroughSubject()
            self._unsubscriptionSubject = PassthroughSubject()
            super.init()
            // 4. The Lighstreamer client stores the delegate weakly, thus there is no reference cycle.
            self._client.addDelegate(self)
        }
        
        deinit {
            self.unsubscribeAll()
            self.disconnect()
            self._statusSubject.send(completion: .finished)
            self._client.removeDelegate(self)
            self._lock.invalidate()
        }
        
        /// The Lightstreamer library version.
        @nonobjc static var lightstreamerVersion: String {
            LSLightstreamerClient.lib_VERSION
        }
    }
}

internal extension Streamer.Channel {
    /// Returns the current session status.
    @nonobjc var status: Streamer.Session.Status {
        self._lock.execute { self._status }
    }
    
    /// Subscribe to the status events and return the output in the given queue.
    /// - remark: The subject never fails and only completes successfully when the `Channel` gets deinitialized.
    /// - parameter queue: `DispatchQueue` were values are received.
    /// - returns: Publisher emitting status values (can be duplicated).
    @nonobjc func statusStream(on queue: DispatchQueue) -> Publishers.ReceiveOn<PassthroughSubject<Streamer.Session.Status,Never>,DispatchQueue> {
        self._statusSubject.receive(on: queue)
    }
    
    /// Tries to connect the low-level client to the lightstreamer server.
    ///
    /// This function will perform work depending on the current status:
    /// - If `.disconnected` and it is not retrying further connection, a full-fledge connection attempt will be made.
    /// - If `.stalled`, an error will be thrown.
    /// - For any other case, the current status is returned and no work will be performed, since the supposition is made that a previous call has been made.
    /// 
    /// - throws: `IG.Error` exclusively when the status is `.stalled`.
    /// - returns: The client status at the time of the call (right before the low-level client calls the underlying *connect*).
    @nonobjc @discardableResult func connect() throws -> Streamer.Session.Status {
        let currentStatus = self.status
        switch currentStatus {
        case .disconnected(isRetrying: false): self._client.connect()
        case .stalled: throw IG.Error._stalledConnection()
        case .connected, .connecting, .disconnected(isRetrying: true): break
        }
        return currentStatus
    }
    
    /// Tries to disconnect the low-level client from the server and returns the current client status.
    ///
    /// If the client is already disconnected, no further work is performed.
    /// - returns: The client status at the time of the call (right before the low-level *disconnection* is called).
    @nonobjc @discardableResult func disconnect() -> Streamer.Session.Status {
        let status = self.status
        if status != .disconnected(isRetrying: false) {
            self._client.disconnect()
        }
        return status
    }
    
    /// Subscribe to the following items and fields (in the given mode) requesting (or not) a snapshot.
    /// - parameter queue: The queue on which value processing will take place.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter items: The item identfiers (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    /// - returns: A publisher forwarding updates as values. This publisher will only stop by not holding a reference to the signal, by interrupting it with a cancellable, or by calling `unsubscribeAll()`
    @nonobjc func subscribe(on queue: DispatchQueue, mode: Streamer.Mode, items: [String], fields: [String], snapshot: Bool) -> Publishers.ReceiveOn<Publishers.PrefixUntilOutput<Streamer.Subscription, PassthroughSubject<(),Never>>,DispatchQueue> {
        Streamer.Subscription(client: self._client, mode: mode, items: items, fields: fields, snapshot: snapshot)
            .prefix(untilOutputFrom: self._unsubscriptionSubject)
            .receive(on: queue)
    }
    
    /// Unsubscribe to all ongoing subscriptions.
    /// - returns: All subscriptions that were active at the time of the call (i.e. right before the unsubscription takes place).
    @nonobjc func unsubscribeAll() {
        self._unsubscriptionSubject.send()
    }
}

// MARK: - Lightstreamer Delegate

extension Streamer.Channel: LSClientDelegate {
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        // 1. Translate from ObjC status to Swift status.
        let receivedStatus = Streamer.Session.Status(rawValue: status) ?! fatalError("Lightstreamer client status '\(status)' was not recognized")
        self._lock.lock()
        // 2. Ignore if the status is the same as the previous one.
        guard self._status != receivedStatus else { return self._lock.unlock() }
        // 3. Safe the new status.
        self._status = receivedStatus
        self._lock.unlock()
        // 4. If the new status is disconnected, close all subscriptions.
        if case .disconnected(isRetrying: false) = receivedStatus { self._unsubscriptionSubject.send() }
        // 5. Communicate downstream the new status.
        self._statusSubject.send(receivedStatus)
    }
    
    //@objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) { }
    //@objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) { }
    //@objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) { }
    //@objc func clientDidAdd(_ client: LSLightstreamerClient) { }
    //@objc func clientDidRemove(_ client: LSLightstreamerClient) { }
}

private extension IG.Error {
    /// Error raised when the server connection is stalled.
    static func _stalledConnection() -> Self {
        Self(.streamer(.invalidRequest), "Stalled streamer connection.", help: "Disconnect and connect again.")
    }
}
