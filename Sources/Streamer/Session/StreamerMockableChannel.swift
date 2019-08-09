import Lightstreamer_macOS_Client
import ReactiveSwift
import Foundation

internal protocol StreamerMockableChannel: class {
    /// Initializes the session setting up all parameters to be ready to connect.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    init(rootURL: URL, credentials: Streamer.Credentials)
    /// Returns the current streamer status.
    var status: Property<Streamer.Session.Status> { get }
    /// Requests to open the session against the Lightstreamer server.
    /// - note: This method doesn't check whether the channel is currently connected or not.
    func connect()
    /// Subscribe to the following item and field (in the given mode) requesting (or not) a snapshot.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter item: The item identfier (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    /// - returns: A producer providing updates as values. The producer will never complete, it will only be stoped by not holding a reference to the signal or by interrupting it with a disposable.
    func subscribe(mode: Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> SignalProducer<[String:Streamer.Subscription.Update],Streamer.Error>
    /// Unsubscribe to all ongoing subscriptions.
    /// - returns: All currently ongoing subscriptions.
    func unsubscribeAll() -> [Streamer.Subscription]
    /// Requests to close the Session opened against the configured Lightstreamer Server (if any).
    /// - note: Active sbuscription instances, associated with this LightstreamerClient instance, are preserved to be re-subscribed to on future Sessions.
    func disconnect()
}
