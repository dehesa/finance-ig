import Lightstreamer_macOS_Client
import ReactiveSwift
import Foundation

/// A streamer channel needs to inherit from this protocol.
///
/// Mainly used for testing.
internal protocol StreamerMockableChannel: class {
    /// Initializes the session setting up all parameters to be ready to connect.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    /// - parameter queue: The `DispatchQueue` processing all new packages. The higher its QoS, the faster packages will be processed.
    /// - note: Each subscription will have its own serial queue and the QoS will get inherited from `queue`.
    init(rootURL: URL, credentials: IG.Streamer.Credentials, queue: DispatchQueue)
    /// Returns the current streamer status.
    var status: Property<IG.Streamer.Session.Status> { get }
    /// Requests to open the session against the Lightstreamer server.
    /// - note: This method doesn't check whether the channel is currently connected or not.
    func connect()
    /// Subscribe to the following item and field (in the given mode) requesting (or not) a snapshot.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter item: The item identfier (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    /// - returns: A producer providing updates as values. The producer will never complete, it will only be stoped by not holding a reference to the signal or by interrupting it with a disposable.
    func subscribe(mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> SignalProducer<[String:IG.Streamer.Subscription.Update],IG.Streamer.Error>
    /// Unsubscribe to all ongoing subscriptions.
    /// - returns: All currently ongoing subscriptions.
    func unsubscribeAll() -> [IG.Streamer.Subscription]
    /// Requests to close the Session opened against the configured Lightstreamer Server (if any).
    /// - note: Active sbuscription instances, associated with this LightstreamerClient instance, are preserved to be re-subscribed to on future Sessions.
    func disconnect()
}
