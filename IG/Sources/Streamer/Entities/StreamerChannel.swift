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
        /// The Combine's *subscriber* for a streamer subscription.
        private typealias SubscriptionSink = Subscribers.Sink<IG.Streamer.Subscription.Event,Never>
        
        /// Streamer credentials used to access the trading platform.
        @nonobjc let credentials: IG.Streamer.Credentials
        /// The low-level lightstreamer client actually performing the network calls.
        /// - seealso: https://www.lightstreamer.com/repo/cocoapods/ls-ios-client/api-ref/2.1.2/classes.html
        @nonobjc private let client: LSLightstreamerClient
        /// All ongoing/active subscriptions paired with the cancellable that will make them stop.
        @nonobjc private var subscriptions: [IG.Streamer.Subscription:SubscriptionSink]
        /// A subject subscribing to the session status.
        @nonobjc private let statusSubject: CurrentValueSubject<IG.Streamer.Session.Status,Never>
        /// The lock used to restrict access to the credentials.
        @nonobjc private let lock: UnsafeMutablePointer<os_unfair_lock>
        
        /// Initializes the session setting up all parameters to be ready to connect.
        /// - parameter rootURL: The URL where the streaming server is located.
        /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
        /// - note: Each subscription will have its own serial queue and the QoS will get inherited from `queue`.
        @nonobjc init(rootURL: URL, credentials: IG.Streamer.Credentials) {
            self.credentials = credentials
            self.lock = UnsafeMutablePointer.allocate(capacity: 1)
            self.lock.initialize(to: os_unfair_lock())
            self.client = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil)
            self.client.connectionDetails.user = credentials.identifier.rawValue
            self.client.connectionDetails.setPassword(credentials.password)
            self.subscriptions = .init()
            self.statusSubject = .init(.disconnected(isRetrying: false))
            super.init()
            
            // The client stores the delegate weakly, therefore there is no reference cycle.
            self.client.add(delegate: self)
        }
        
        deinit {
            self.client.remove(delegate: self)
            self.unsubscribeAll()
            self.disconnect()
            self.lock.deallocate()
        }
        
        /// The Lightstreamer library version.
        static var lightstreamerVersion: String {
            return LSLightstreamerClient.lib_VERSION
        }
        
        /// Returns the number of subscriptions currently established (and working) at the moment.
        public final var ongoingSubscriptions: Int {
            os_unfair_lock_lock(self.lock)
            let numSubscriptions = self.subscriptions.count
            os_unfair_lock_unlock(self.lock)
            return numSubscriptions
        }
    }
}

extension IG.Streamer.Channel {
    /// Returns the current session status.
    @nonobjc var status: IG.Streamer.Session.Status {
        self.statusSubject.value
    }
    
    /// Subscribe to the status events and return the output in the given queue.
    ///
    /// - remark: This publisher filter out any status duplication; therefore each event is unique.
    /// - parameter queue: `DispatchQueue` were values are received.
    @nonobjc func subscribeToStatus(on queue: DispatchQueue) -> Combine.Publishers.RemoveDuplicates<Combine.Publishers.ReceiveOn<CurrentValueSubject<Streamer.Session.Status,Never>, DispatchQueue>> {
        return self.statusSubject.receive(on: queue).removeDuplicates()
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
        case .stalled: throw IG.Streamer.Error.invalidRequest("The Streamer is connected, but silent", suggestion: "Disconnect and connect again")
        case .disconnected(isRetrying: false): self.client.connect()
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
            self.client.disconnect()
        }
        return status
    }
    
    /// Subscribe to the following item and field (in the given mode) requesting (or not) a snapshot.
    /// - parameter queue: The queue on which value processing will take place.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter item: The item identfier (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    /// - returns: A publisher forwarding updates as values. This publisher will only stop by not holding a reference to the signal, by interrupting it with a cancellable, or by calling `unsubscribeAll()`
    @nonobjc func subscribe(on queue: DispatchQueue, mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> IG.Streamer.Publishers.Continuous<IG.Streamer.Packet> {
        /// Keeps the necessary state to clean up the *slate* once the subscription finishes or cancels.
        var state: IG.Streamer.Subscription? = nil
        /// When triggered, it unsubscribe and clean any possible state where the subscription has been.
        let cleanUp: ()->Void = { [weak self] in
            guard let self = self else { state = nil; return }
            
            os_unfair_lock_lock(self.lock)
            guard let subscription = state else {
                return os_unfair_lock_unlock(self.lock)
            }
            
            state = nil
            let subscriber = self.subscriptions.removeValue(forKey: subscription)
            os_unfair_lock_unlock(self.lock)
            
            subscriber?.cancel()
            guard subscription.lowlevel.isActive else { return }
            self.client.unsubscribe(subscription.lowlevel)
        }
        
        return DeferredPassthrough<IG.Streamer.Packet,IG.Streamer.Error> { [weak self, weak weakQueue = queue] (subject) in
                guard let self = self, let queue = weakQueue else {
                    return subject.send(completion: .failure(.sessionExpired()))
                }
                
                let subscription = IG.Streamer.Subscription(mode: mode, item: item, fields: fields, snapshot: snapshot)
                // The `sink` will only complete if `unsubscribeAll()` is called. In any other case, it is cancelled silently.
                let sink = SubscriptionSink(receiveCompletion: { [weak subject] _ in
                    subject?.send(completion: .finished)
                }, receiveValue: { [weak subject] (event) in
                    switch event {
                    case .updateReceived(let update):
                        subject?.send(update)
                    case .subscribed:
                        #if DEBUG
                        print("\(IG.Streamer.printableDomain): Subscription to \(item) established")
                        #endif
                        break
                    case .updateLost(let count, let receivedItem):
                        #if DEBUG
                        print("\(IG.Streamer.printableDomain): Subscription to \(receivedItem ?? item) lost \(count) updates. Fields: [\(fields.joined(separator: ","))]")
                        #endif
                        break
                    case .error(let e):
                        let message = "The subscription couldn't be established"
                        let error: IG.Streamer.Error = .subscriptionFailed(.init(message), item: item, fields: fields, underlying: e, suggestion: .reviewError)
                        subject?.send(completion: .failure(error))
                    case .unsubscribed:
                        #if DEBUG
                        print("\(IG.Streamer.printableDomain): Unsubscribed to \(item)")
                        #endif
                        subject?.send(completion: .finished)
                    }
                })
            
                os_unfair_lock_lock(self.lock)
                state = subscription
                self.subscriptions[subscription] = sink
                os_unfair_lock_unlock(self.lock)
                
                subscription.subscribeToStatus(on: queue).subscribe(sink)
                self.client.subscribe(subscription.lowlevel)
            }.handleEvents(receiveCompletion: { _ in cleanUp() }, receiveCancel: cleanUp)
            .eraseToAnyPublisher()
    }
    
    /// Unsubscribe to all ongoing subscriptions.
    /// - returns: All subscriptions that were active at the time of the call (i.e. right before the unsubscription takes place).
    @nonobjc @discardableResult func unsubscribeAll() -> [String] {
        os_unfair_lock_lock(self.lock)
        let subscriptions = self.subscriptions
        self.subscriptions.removeAll()
        os_unfair_lock_unlock(self.lock)
        
        for (_, sink) in subscriptions {
            sink.receive(completion: .finished)
        }
        
        return subscriptions.keys.map { $0.item }
    }
}

// MARK: - Lightstreamer Delegate

extension IG.Streamer.Channel: LSClientDelegate {
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        guard let receivedStatus = IG.Streamer.Session.Status(rawValue: status) else {
            fatalError("Lightstreamer client status \"\(status)\" was not recognized")
        }
        
        self.statusSubject.send(receivedStatus)
    }
    
    //@objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) { <#code#> }
    //@objc func didAddDelegate(to: LSLightstreamerClient) { <#code#> }
    //@objc func didRemoveDelegate(to: LSLightstreamerClient) { <#code#> }
}
