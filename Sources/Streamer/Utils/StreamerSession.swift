import Foundation

/// Protocol for the streaming session allowing it to be mocked from the test framework.
internal protocol StreamerSession: class {
    /// Creates an object to be configured to connect to a Lightstreamer server and to handle all the communications with it.
    ///
    /// Each LSLightstreamerClient is the entry point to connect to a Lightstreamer server, subscribe to as many items as needed and to send messages.
    /// - parameter serverAddress: The address of the Lightstreamer Server to which this LightstreamerClient will connect to. It is possible to specify it later by using nil here. See `LSConnectionDetails.serverAddress` for details.
    /// - parameter adapterSet: The name of the Adapter Set mounted on Lightstreamer Server to be used to handle all requests in the Session associated with this LightstreamerClient. It is possible not to specify it at all or to specify it later by using nil here. See LSConnectionDetails#adapterSet for details.
    init(serverAddress: String?, adapterSet: String?)
    
    /// Current client status and transport (when applicable).
    /// - `CONNECTING` the client is waiting for a Server's response in order to establish a connection;
    /// - `CONNECTED:STREAM-SENSING` the client has received a preliminary response from the server and is currently verifying if a streaming connection is possible;
    /// - `CONNECTED:WS-STREAMING` a streaming connection over WebSocket is active;
    /// - `CONNECTED:HTTP-STREAMING` a streaming connection over HTTP is active;
    /// - `CONNECTED:WS-POLLING` a polling connection over WebSocket is in progress;
    /// - `CONNECTED:HTTP-POLLING` a polling connection over HTTP is in progress;
    /// - `STALLED` the Server has not been sending data on an active streaming connection for longer than a configured time;
    /// - `DISCONNECTED` no connection is currently active;
    /// - `DISCONNECTED:WILL-RETRY` no connection is currently active but one will be open after a timeout.
    /// - returns: The current client status. It can be one of the following values: <ul>
    var status: String { get }
    
    /// List containing the LSClientDelegate instances that were added to this client.
    /// - returns: a list containing the delegates that were added to this client.
    var delegates: [Any] { get }
    
    /// Adds a delegate that will receive events from the `LSLightstreamerClient` instance.
    ///
    /// The same delegate can be added to several different `LSLightstreamerClient` instances.
    /// A delegate can be added at any time. A call to add a delegate already present will be ignored.
    /// parameter delegate: An object that will receive the events as documented in the LSClientDelegate interface.
    /// - note: delegates are stored with weak references: make sure you keep a strong reference to your delegates or they may be released prematurely.
    func add(delegate: StreamerSessionDelegate)
    
    /// Removes a delegate from the `LSLightstreamerClient` instance so that it will not receive events anymore.
    /// A delegate can be removed at any time.
    /// - parameter delegate: The delegate to be removed.
    func remove(delegate: StreamerSessionDelegate)
    
    /// Operation method that requests to open a Session against the configured Lightstreamer Server.
    ///
    /// When `connect()` is called, unless a single transport was forced through `LSConnectionOptions.forcedTransport`, the so called "Stream-Sense" mechanism is started:
    /// - if the client does not receive any answer for some seconds from the streaming connection, then it will automatically open a polling connection.
    /// - A polling connection may also be opened if the environment is not suitable for a streaming connection.
    ///
    /// When the request to connect is finally being executed, if the current status of the client is `CONNECTING`, `CONNECTED:*` or `STALLED`, then nothing will be done.
    /// - note: As "polling connection" we mean a loop of polling requests, each of which requires opening a synchronous (i.e. not streaming) connection to Lightstreamer Server. Note that the request to connect is accomplished by the client in a separate thread; this means that an invocation of #status right after #connect might not reflect the change yet.
    func connect()
    
    /// Operation method that requests to close the Session opened against the configured Lightstreamer Server (if any).
    ///
    /// When `disconnect()` is called, the "Stream-Sense" mechanism is stopped.
    ///
    /// When the request to disconnect is finally being executed, if the status of the client is `DISCONNECTED`, then nothing will be done.
    /// - note: Active `LSSubscription` instances, associated with this LightstreamerClient instance, are preserved to be re-subscribed to on future Sessions.
    /// -note: The request to disconnect is accomplished by the client in a separate thread; this means that an invocation of `status` right after `disconnect()` might not reflect the change yet.
    func disconnect()
    
    /// Creates a temporary subscription session managing the input/output for a subscription.
    /// - parameter mode: The type of subscription.
    /// - parameter items: The names of the items to be subscribed.
    /// - parameter fields: The fields to be subscribed to.
    func makeSubscriptionSession<F:StreamerField>(mode: Streamer.Mode, items: Set<String>, fields: Set<F>) -> StreamerSubscriptionSession
    
    /// List containing all the `LSSubscription` instances that are currently "active" on this LightstreamerClient.
    ///
    /// Internal second-level `LSSubscription` are not included.
    /// - returns: A list, containing all the LSSubscription currently "active" on this LSLightstreamerClient. The list can be empty.
    var subscriptions: [Any] { get }
    
    /// Operation method that adds a subscription to the list of "active" subscriptions.
    ///
    /// The subscription cannot already be in the "active" state. Active subscriptions are subscribed to through the server as soon as possible (i.e. as soon as there is a session available). Active subscription are automatically persisted across different sessions as long as a related unsubscribe call is not issued. Subscriptions can be given to the `StreamerSession` at any time. Once done the subscription immediately enters the "active" state.
    ///
    /// Once "active", a subscription cannot be provided again to a `StreamerSession` unless it is first removed from the "active" state through a call to `unsubscribe(to:)`.
    ///
    /// A successful subscription to the server will be notified through a `StreamerSubscriptionDelegate`'s `subscribed(to:)` function.
    /// - note: forwarding of the subscription to the server is made in a separate thread.
    /// - parameter subscription: A subscription object, carrying all the information needed to process its pushed values.
    func subscribe(to subscription: StreamerSubscriptionSession)
    
    
    /// Operation method that removes a subscription that is currently in the "active" state.
    ///
    /// By bringing back a subscription to the "inactive" state, the unsubscription from all its items is requested to Lightstreamer Server. Subscription can be unsubscribed from at any time. Once done the subscription immediately exits the "active" state.
    ///
    /// The unsubscription will be notified through the `StreamerSubscriptionDelegate`'s `unsubscribed(to:)` function.
    /// - note: Forwarding of the unsubscription to the server is made in a separate thread.
    /// - parameter subscription: An "active" subscription object that was activated by this `StreamerSession` instance.
    func unsubscribe(from subscription: StreamerSubscriptionSession)
}

extension StreamerSession {
    /// Unsubscribes all active subscriptions.
    func unsubscribeAll() {
        for subscription in self.subscriptions as! [StreamerSubscriptionSession] {
            guard subscription.isActive else { continue }
            self.unsubscribe(from: subscription)
        }
    }
}

/// Delegate for all messages the session can send.
internal protocol StreamerSessionDelegate: class {
    /// Event handler that receives a notification each time the LSLightstreamerClient status has changed.
    ///
    /// The status changes may be originated either by custom actions (e.g. by calling `LSLightstreamerClient.disconnect`) or by internal actions.
    func statusChanged(to status: Streamer.Status, on session: StreamerSession)
}
