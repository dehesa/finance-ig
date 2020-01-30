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
        /// The lock used to restrict access to the credentials.
        @nonobjc private let lock: UnsafeMutablePointer<os_unfair_lock>
        /// The low-level lightstreamer client actually performing the network calls.
        /// - seealso: https://www.lightstreamer.com/repo/cocoapods/ls-ios-client/api-ref/2.1.2/classes.html
        @nonobjc private let client: LSLightstreamerClient
        /// All ongoing/active subscriptions paired with the cancellable that will make them stop.
        @nonobjc private var subscriptions: [IG.Streamer.Subscription:SubscriptionSink] = .init()
        
        /// Returns a `CurrentValueSubject` to subscribe to  the current channel status.
        ///
        /// This publisher remove duplicates (i.e. there aren't any repeating statuses) and it always returns the current status upon activation.
        /// - important: This publisher returns value on the Lightstreamer low-level queue. Change queues as soon as possible to let the low-level layers continue processing incoming network pacakges.
        @nonobjc private let mutableStatus: CurrentValueSubject<IG.Streamer.Session.Status,Never>
        
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
            self.mutableStatus = .init(.disconnected(isRetrying: false))
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
    /// Returns a publisher to subscribe to status events (the current value is sent first).
    ///
    /// This publisher remove duplicates (i.e. there aren't any repeating statuses) and it always returns the current status upon activation.
    /// - important: This publisher returns value on the priviledge queue. Change queues as soon as possible to let the low-level layers continue processing incoming network pacakges.
    @nonobjc var status: some CurrentStatusPublisher {
        return self.mutableStatus
    }
    
    /// Tries to connect the low-level client to the server and returns the current client status.
    ///
    /// The connection process takes some time; If the returned status is not `.connected`, then you need to subscribe to the client's statuses and wait for the proper status.
    /// - returns: The client status at the time of the call.
    @nonobjc @discardableResult func connect() throws -> IG.Streamer.Session.Status {
        os_unfair_lock_lock(self.lock)
        let currentStatus = self.mutableStatus.value
        os_unfair_lock_unlock(self.lock)
        
        switch currentStatus {
        case .stalled: throw IG.Streamer.Error.invalidRequest("The Streamer is connected, but silent", suggestion: "Disconnect and connect again")
        case .disconnected(isRetrying: false): self.client.connect()
        case .connected, .connecting, .disconnected(isRetrying: true): break
        }
        return currentStatus
    }
    
    /// Tries to disconnect the low-level client from the server and returns the current client status.
    /// - returns: The client status at the time of the call.
    @nonobjc @discardableResult func disconnect() -> IG.Streamer.Session.Status {
        os_unfair_lock_lock(self.lock)
        let currentStatus = self.mutableStatus.value
        os_unfair_lock_unlock(self.lock)
        
        if currentStatus != .disconnected(isRetrying: false) {
            self.client.disconnect()
        }
        return currentStatus
    }
    
    /// Subscribe to the following item and field (in the given mode) requesting (or not) a snapshot.
    /// - important: This publisher returns values on the Lightstreamer low-level queue. Change queues as soon as possible to let the low-level layers continue processing incoming network pacakges.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter item: The item identfier (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    /// - returns: A publisher forwarding updates as values. This publisher will only stop by not holding a reference to the signal, by interrupting it with a cancellable, or by calling `unsubscribeAll()`
    @nonobjc func subscribe(mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> IG.Streamer.Publishers.Continuous<[String:IG.Streamer.Subscription.Update]> {
        /// Keeps the necessary state to clean up the *slate* once the subscription finishes or cancels.
        var state: IG.Streamer.Subscription? = nil
        /// When triggered, it unsubscribe and clean any possible state where the subscription has been.
        let cleanUp: ()->Void = { [weak self] in
            guard let self = self else { return }
            
            os_unfair_lock_lock(self.lock)
            guard let subscription = state else {
                return os_unfair_lock_unlock(self.lock)
            }
            
            state = nil
            let subscriber = self.subscriptions.removeValue(forKey: subscription)
            os_unfair_lock_unlock(self.lock)
            
            subscriber?.cancel()
            if subscription.lowlevel.isActive {
                self.client.unsubscribe(subscription.lowlevel)
            }
        }
        
        return DeferredPassthrough<[String:IG.Streamer.Subscription.Update],IG.Streamer.Error> { [weak self] (subject) in
                guard let self = self else {
                    return subject.send(completion: .failure(.sessionExpired()))
                }
                
                let subscription = IG.Streamer.Subscription(mode: mode, item: item, fields: fields, snapshot: snapshot)
                // The `sink` will only complete if `unsubscribeAll()` is called. In any other case, it is cancelled silently.
                let sink = SubscriptionSink.init(receiveCompletion: { [weak subject] _ in
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
                
                subscription.status.dropFirst().subscribe(sink)
                self.client.subscribe(subscription.lowlevel)
            }.handleEvents(receiveCompletion: { _ in cleanUp() }, receiveCancel: cleanUp)
            .eraseToAnyPublisher()
    }
    
    /// Unsubscribe to all ongoing subscriptions.
    /// - returns: All subscriptions that were active at the time of the call.
    @nonobjc @discardableResult func unsubscribeAll() -> [IG.Streamer.Subscription] {
        os_unfair_lock_lock(self.lock)
        let subscriptions = self.subscriptions
        self.subscriptions.removeAll()
        os_unfair_lock_unlock(self.lock)
        
        for (subscription, sink) in subscriptions {
            sink.receive(completion: .finished)
            if subscription.lowlevel.isActive {
                self.client.unsubscribe(subscription.lowlevel)
            }
        }
        return .init(subscriptions.keys)
    }
}

// MARK: - Lightstreamer Delegate

extension IG.Streamer.Channel: LSClientDelegate {
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        guard let receivedStatus = IG.Streamer.Session.Status(rawValue: status) else {
            fatalError("Lightstreamer client status \"\(status)\" was not recognized")
        }
        
        os_unfair_lock_lock(self.lock)
        let storedStatus = self.mutableStatus.value
        os_unfair_lock_unlock(self.lock)
        
        guard storedStatus != receivedStatus else { return }
        self.mutableStatus.send(receivedStatus)
    }
    //@objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) { <#code#> }
    //@objc func didAddDelegate(to: LSLightstreamerClient) { <#code#> }
    //@objc func didRemoveDelegate(to: LSLightstreamerClient) { <#code#> }
}

// MARK: - Combine Extensions

/// Returns the receiving's publisher current value.
public protocol CurrentStatusPublisher: Publisher where Output==IG.Streamer.Session.Status, Failure==Never {
    /// The value wrapped by this subject, published as a new element whenever it changes.
    var value: Output { get }
}

extension CurrentValueSubject: CurrentStatusPublisher where Output==IG.Streamer.Session.Status, Failure==Never {}
