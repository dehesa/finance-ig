import Foundation

/// Protocol that all subscription instances must inherit.
///
/// The functionality is extracted away from the subscription class so it can be mocked.
internal protocol StreamerSubscriptionSession: class {
    /// The Lightstreamer mode.
    var mode: String { get }
    /// The "Item List" to be subscribed to through Server.
    var items: [Any]? { get }
    /// The "Field List" to be subscribed to through Server.
    var fields: [Any]? { get }
    /// Checks if the Subscription is currently "active" or not.
    /// The status of a Subscription is changed to "active" through when the session "subscribe" and back to "inactive" when the session "unsubscribe".
    var isActive: Bool { get }
    /// Checks if the subscription is currently subscribed to through the server or not.
    /// This flag is switched to `true` by server sent subscription events, and back to `false` in case of client disconnection, session unsubscription calls and server sent unsubscription events.
    var isSubscribed: Bool { get }
    /// Adds a delegate that will receive events from the receiving subscription instance.
    ///
    /// The same delegate can be added to several different subscription instances.
    ///
    /// A delegate can be added at any time. A call to add a delegate already present will be ignored.
    /// - note: delegates are stored with weak references: make sure you keep a strong reference to your delegates or they may be released prematurely.
    func add(delegate: StreamerSubscriptionDelegate)
    /// Removes a delegate from the LSSubscription instance so that it will not receive events anymore.
    ///
    /// A delegate can be removed at any time.
    func remove(delegate: StreamerSubscriptionDelegate)
}

/// Delegate for all messages the subscription can send.
internal protocol StreamerSubscriptionDelegate: class {
    /// Event handler that notifies that a subscription has been successfully subscribed to through the Server.
    ///
    /// This can happen multiple times in the life of a subscription instance, in case the Subscription is performed multiple times through unsubscribe/subscribe pairs. This can also happen multiple times in case of automatic recovery after a connection restart.
    ///
    /// However, two consecutive calls to this method are not possible, as before a second `subscribed(to:)` event is fired an `unsubscribed(to:)`. event is eventually fired.
    /// - note: This notification is always issued before the other ones related to the same subscription. It invalidates all data that has been received previously.
    func subscribed(to subscription: StreamerSubscriptionSession)
    /// Event handler that is called each time an update pertaining to an item in the subscription has been received from the Server.
    /// - parameter update: The update package/instance received from the server containing the values and some meta-information.
    /// - parameter subscription: The instance containing the subscription information.
    func updateReceived(_ update: StreamerSubscriptionUpdate, from subscription: StreamerSubscriptionSession)
    /// Event handler that notifies that, due to internal resource limitations, the Server dropped one or more updates for an item in the Subscription.
    ///
    /// Such notifications are sent only if the items are delivered in an unfiltered mode; this occurs if the subscription mode is:
    /// - `.raw`
    /// - `.merge` or `.distinct`, with unfiltered dispatching specified.
    /// - `.command` with or without unfiltered dispatching specified.
    ///
    /// By implementing this method it is possible to perform recovery actions.
    /// - parameter count: The number of consecutive updates dropped for the item.
    /// - parameter subscription: The instance containing the subscription information.
    /// - parameter item: The item name and position.
    func updatesLost(count: UInt, from subscription: StreamerSubscriptionSession, item: (name: String?, position: UInt))
    /// Event handler that is called when the Server notifies an error on a subscription.
    /// - parameter subscription: The instance containing the subscription information.
    /// - parameter error: Error structure containing the cause of the error and some debug message.
    func subscriptionFailed(to subscription: StreamerSubscriptionSession, error: Streamer.Subscription.Error)
    /// Event handler that notifies a subscription has been successfully unsubscribed from.
    ///
    /// This can happen multiple times in the life of a subscription instance, in case the Subscription is performed multiple times through unsubscribe/subscribe pairs. This can also happen multiple times in case of automatic recovery after a connection restart.
    ///
    /// However, two consecutive calls to this method are not possible, as before a second `subscribed(to:)` event is fired an `unsubscribed(to:)`. event is eventually fired.
    /// - note: After this notification, no more events can be received until a resubscription is tried.
    func unsubscribed(to subscription: StreamerSubscriptionSession)
}

/// Container for values and meta-information on an update received by the server.
internal protocol StreamerSubscriptionUpdate: class {
    /// The name of the item to which this update pertains.
    var item: String { get }
    /// Tells whether the current update belongs to the item snapshot (which carries the current item state at the time of Subscription).
    var isSnapshot: Bool { get }
    /// Key/values for all fields/properties in the subscription.
    var all: [String:String] { get }
    /// Key/values for the delta of fields/properties that changed on the last iteration.
    var latest: [String:String] { get }
}

/// A type that can be initialized with a low level subscription update package.
internal protocol StreamerUpdatable {
    /// Designated initializer accepting an update package.
    /// - parameter update: The update coming from the subscription session.
    /// - throws: It only throws `Streamer.Error` types.
    init(update: StreamerSubscriptionUpdate) throws
}
