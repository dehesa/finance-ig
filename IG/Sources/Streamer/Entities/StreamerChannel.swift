#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#else
#error("OS currently not supported")
#endif
import Conbini
import Combine
import Foundation

extension IG.Streamer {
    /// Contains all functionality related to the Streamer session.
    internal final class Channel: NSObject {
        /// Streamer credentials used to access the trading platform.
        @nonobjc let credentials: IG.Streamer.Credentials
        
        /// The low-level lightstreamer client actually performing the network calls.
        /// - seealso: https://www.lightstreamer.com/repo/cocoapods/ls-ios-client/api-ref/2.1.2/classes.html
        @nonobjc private let _client: LSLightstreamerClient
        /// A subject subscribing to the session status.
        ///
        /// When the `Channel` is deinitialized, the subject sends a completion event.
        @nonobjc private let _statusSubject: PassthroughSubject<IG.Streamer.Session.Status,Never>
        /// Sends a `()` everytime a unsubscription is requested.
        @nonobjc private let _unsubscriptionSubject: PassthroughSubject<(),Never>
        
        /// Initializes the session setting up all parameters to be ready to connect.
        /// - parameter rootURL: The URL where the streaming server is located.
        /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
        /// - note: Each subscription will have its own serial queue and the QoS will get inherited from `queue`.
        @nonobjc init(rootURL: URL, credentials: IG.Streamer.Credentials) {
            self.credentials = credentials
            self._client = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil)
            self._client.connectionDetails.user = credentials.identifier.rawValue
            self._client.connectionDetails.setPassword(credentials.password)
            self._statusSubject = .init()
            self._unsubscriptionSubject = .init()
            super.init()
            
            // The client stores the delegate weakly, therefore there is no reference cycle.
            self._client.add(delegate: self)
        }
        
        deinit {
            self._client.remove(delegate: self)
            self.unsubscribeAll()
            self.disconnect()
        }
        
        /// The Lightstreamer library version.
        static var lightstreamerVersion: String {
            LSLightstreamerClient.lib_VERSION
        }
    }
}

internal extension IG.Streamer.Channel {
    /// Returns the current session status.
    @nonobjc var status: IG.Streamer.Session.Status {
        return IG.Streamer.Session.Status(rawValue: self._client.status) ?! fatalError()
    }
    
    /// Subscribe to the status events and return the output in the given queue.
    /// - parameter queue: `DispatchQueue` were values are received.
    /// - returns: Publisher emitting status values (can be duplicated) and never completing.
    @nonobjc func statusStream(on queue: DispatchQueue) -> Publishers.ReceiveOn<PassthroughSubject<Streamer.Session.Status,Never>,DispatchQueue> {
        self._statusSubject.receive(on: queue)
    }
    
    /// Tries to connect the low-level client to the lightstreamer server.
    ///
    /// This function will perform work depending on the current status:
    /// - If `.disconnected` and it is not retrying further connection, a full-fledge connection attempt will be made.
    /// - If `.stalled`, an error will be thrown.
    /// - For any other case, the current status is returned and no work will be performed, since the supposition is made that a previous call has been made.
    /// - throws: `IG.Streamer.Error.invalidRequest` exclusively when the status is `.stalled`.
    /// - returns: The client status at the time of the call (right before the low-level client calls the underlying *connect*).
    @nonobjc @discardableResult func connect() throws -> IG.Streamer.Session.Status {
        let currentStatus = self.status
        switch currentStatus {
        case .disconnected(isRetrying: false): self._client.connect()
        case .stalled: throw IG.Streamer.Error.invalidRequest("The Streamer is connected, but silent", suggestion: "Disconnect and connect again")
        case .connected, .connecting, .disconnected(isRetrying: true): break
        }
        return currentStatus
    }
    
    /// Tries to disconnect the low-level client from the server and returns the current client status.
    ///
    /// If the client is already disconnected, no further work is performed.
    /// - returns: The client status at the time of the call (right before the low-level *disconnection* is called).
    @nonobjc @discardableResult func disconnect() -> IG.Streamer.Session.Status {
        let status = self.status
        if status != .disconnected(isRetrying: false) {
            self._client.disconnect()
        }
        return status
    }
    
    /// Subscribe to the following item and field (in the given mode) requesting (or not) a snapshot.
    ///
    /// The returned publisher only fails with `IG.Streamer.Error`. That information is left out for optimization purposes.
    /// - parameter queue: The queue on which value processing will take place.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter item: The item identfier (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    /// - returns: A publisher forwarding updates as values. This publisher will only stop by not holding a reference to the signal, by interrupting it with a cancellable, or by calling `unsubscribeAll()`
    @nonobjc func subscribe(on queue: DispatchQueue, mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> AnyPublisher<IG.Streamer.Packet,Swift.Error> {
        // 1. Prepare the subscription.
        Deferred { [weak self, weak weakQueue = queue] () -> Result<(DispatchQueue,IG.Streamer.Subscription),IG.Streamer.Error>.Publisher in
                guard case .some = self, let queue = weakQueue else { return .init(.failure(.sessionExpired())) }
                let subscription = IG.Streamer.Subscription(mode: mode, item: item, fields: fields, snapshot: snapshot)
                return .init((queue, subscription))
            // 2. Subscribe to the subscription status.
            }.flatMap { [client = self._client, subject = self._unsubscriptionSubject] (queue, subscription) in
                subscription.subscribeToStatus(on: queue)
                    // 3. In case of `unsubscribeAll()` finish the pipeline.
                    .prefix(untilOutputFrom: subject)
                    // 4. Subscribe/Unsubscribe in the Lightstreamer layers.
                    .handleEvents(receiveSubscription: { (_) in client.subscribe(subscription.lowlevel) },
                                  receiveCompletion: { (_) in client.unsubscribe(subscription.lowlevel) },
                                  receiveCancel: { client.unsubscribe(subscription.lowlevel) })
                    .setFailureType(to: IG.Streamer.Error.self)
            // 5. Map the subscription event, letting pass the updates, ignoring the lost packages, and throwing errors for any other case.
            }.tryCompactMap { (event) -> IG.Streamer.Packet? in
                print(event)
                switch event {
                case .updateReceived(let update):
                    return update
                case .subscribed: // print("\(IG.Streamer.printableDomain): Subscription to \(item) established")
                    return nil
                case .updateLost://(let count, let receivedItem): print("\(IG.Streamer.printableDomain): Subscription to \(receivedItem ?? item) lost \(count) updates. Fields: [\(fields.joined(separator: ","))]")
                    return nil
                case .error(let e):
                    let message = "The subscription couldn't be established"
                    throw IG.Streamer.Error.subscriptionFailed(.init(message), item: item, fields: fields, underlying: e, suggestion: .reviewError)
                case .unsubscribed:
                    let message = "Unsubscribed event received from the underlying Lightstreamer layer"
                    throw IG.Streamer.Error.subscriptionFailed(.init(message), item: item, fields: fields, suggestion: .reviewError)
                }
            }.eraseToAnyPublisher()
    }
    
    /// Unsubscribe to all ongoing subscriptions.
    /// - returns: All subscriptions that were active at the time of the call (i.e. right before the unsubscription takes place).
    @nonobjc func unsubscribeAll() {
        self._unsubscriptionSubject.send(())
    }
}

// MARK: - Lightstreamer Delegate

extension IG.Streamer.Channel: LSClientDelegate {
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        guard let receivedStatus = IG.Streamer.Session.Status(rawValue: status) else {
            fatalError("Lightstreamer client status '\(status)' was not recognized")
        }
        
        self._statusSubject.send(receivedStatus)
    }
    
    //@objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) { }
    //@objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) { }
    //@objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) { }
    //@objc func didAddDelegate(to: LSLightstreamerClient) { }
    //@objc func didRemoveDelegate(to: LSLightstreamerClient) { }
}
