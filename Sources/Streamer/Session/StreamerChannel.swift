import Lightstreamer_macOS_Client
import ReactiveSwift
import Foundation

internal protocol StreamerMockableChannel {
    /// Initializes the session setting up all parameters to be ready to connect.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    init(rootURL: URL, credentials: Streamer.Credentials)
    /// Returns the current streamer status.
    var status: Property<Streamer.Session.Status> { get }
    /// Requests to open the session against the Lightstreamer server.
    func connect()
    /// Requests to close the Session opened against the configured Lightstreamer Server (if any).
    func disconnect()
}

extension Streamer {
    /// Contains all functionality related to the Streamer session.
    internal final class Channel: NSObject {
        /// Streamer credentials used to access the trading platform.
        @nonobjc private let credentials: Streamer.Credentials
        /// The central queue handling all events within the Streamer flow.
        @nonobjc private let queue: DispatchQueue
        /// The low-level lightstreamer client actually performing the network calls.
        @nonobjc private let client: LSLightstreamerClient
        
        @nonobjc var status: Property<Streamer.Session.Status> { return self.mutableStatus.skipRepeats() }
        /// Returns the current streamer status.
        @nonobjc private let mutableStatus: MutableProperty<Streamer.Session.Status>
        
        @nonobjc init(rootURL: URL, credentials: Streamer.Credentials) {
            self.credentials = credentials
            
            let label = Bundle(for: Streamer.self).bundleIdentifier! + ".streamer"
            self.queue = DispatchQueue(label: label, qos: .realTimeMessaging, attributes: .concurrent, autoreleaseFrequency: .never)
            
            self.client = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil)
            self.client.connectionDetails.user = credentials.identifier
            self.client.connectionDetails.setPassword(credentials.password)
            self.mutableStatus = MutableProperty<Streamer.Session.Status>(.disconnected(isRetrying: false))
            super.init()
            // The client stores the delegate weakly, therefore there is no reference cycle.
            self.client.addDelegate(self)
        }
        
        deinit {
            self.client.removeDelegate(self)
        }
    }
}

extension Streamer.Channel: StreamerMockableChannel {
    @nonobjc func connect() {
        self.client.connect()
    }
    
    @nonobjc func disconnect() {
        self.client.disconnect()
    }
}

// MARK: - Lightstreamer Delegate

extension Streamer.Channel: LSClientDelegate {
    //@objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) { <#code#> }
    //@objc func clientDidAdd(_ client: LSLightstreamerClient) { <#code#> }
    //@objc func clientDidRemove(_ client: LSLightstreamerClient) { <#code#> }
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        guard let result = Streamer.Session.Status(rawValue: status) else {
            fatalError("Lightstreamer client status \"\(status)\" was not recognized.")
        }
        
        self.queue.async { [property = self.mutableStatus] in
            property.value = result
        }
    }
}

//internal protocol StreamerSession: class {
//    /// Operation method that requests to close the Session opened against the configured Lightstreamer Server (if any).
//    ///
//    /// When `disconnect()` is called, the "Stream-Sense" mechanism is stopped.
//    ///
//    /// When the request to disconnect is finally being executed, if the status of the client is `DISCONNECTED`, then nothing will be done.
//    /// - note: Active `LSSubscription` instances, associated with this LightstreamerClient instance, are preserved to be re-subscribed to on future Sessions.
//    /// -note: The request to disconnect is accomplished by the client in a separate thread; this means that an invocation of `status` right after `disconnect()` might not reflect the change yet.
//    func disconnect()
//
//    /// Creates a temporary subscription session managing the input/output for a subscription.
//    /// - parameter mode: The type of subscription.
//    /// - parameter items: The names of the items to be subscribed.
//    /// - parameter fields: The fields to be subscribed to.
//    func makeSubscriptionSession<F:StreamerField>(mode: Streamer.Mode, items: Set<String>, fields: Set<F>) -> StreamerSubscriptionSession
//
//    /// List containing all the `LSSubscription` instances that are currently "active" on this LightstreamerClient.
//    ///
//    /// Internal second-level `LSSubscription` are not included.
//    /// - returns: A list, containing all the LSSubscription currently "active" on this LSLightstreamerClient. The list can be empty.
//    var subscriptions: [Any] { get }
//
//    /// Operation method that adds a subscription to the list of "active" subscriptions.
//    ///
//    /// The subscription cannot already be in the "active" state. Active subscriptions are subscribed to through the server as soon as possible (i.e. as soon as there is a session available). Active subscription are automatically persisted across different sessions as long as a related unsubscribe call is not issued. Subscriptions can be given to the `StreamerSession` at any time. Once done the subscription immediately enters the "active" state.
//    ///
//    /// Once "active", a subscription cannot be provided again to a `StreamerSession` unless it is first removed from the "active" state through a call to `unsubscribe(to:)`.
//    ///
//    /// A successful subscription to the server will be notified through a `StreamerSubscriptionDelegate`'s `subscribed(to:)` function.
//    /// - note: forwarding of the subscription to the server is made in a separate thread.
//    /// - parameter subscription: A subscription object, carrying all the information needed to process its pushed values.
//    func subscribe(to subscription: StreamerSubscriptionSession)
//
//
//    /// Operation method that removes a subscription that is currently in the "active" state.
//    ///
//    /// By bringing back a subscription to the "inactive" state, the unsubscription from all its items is requested to Lightstreamer Server. Subscription can be unsubscribed from at any time. Once done the subscription immediately exits the "active" state.
//    ///
//    /// The unsubscription will be notified through the `StreamerSubscriptionDelegate`'s `unsubscribed(to:)` function.
//    /// - note: Forwarding of the unsubscription to the server is made in a separate thread.
//    /// - parameter subscription: An "active" subscription object that was activated by this `StreamerSession` instance.
//    func unsubscribe(from subscription: StreamerSubscriptionSession)
//}
//
//extension StreamerSession {
//    /// Unsubscribes all active subscriptions.
//    func unsubscribeAll() {
//        for subscription in self.subscriptions as! [StreamerSubscriptionSession] {
//            guard subscription.isActive else { continue }
//            self.unsubscribe(from: subscription)
//        }
//    }
//}
