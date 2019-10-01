import Combine
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
    var status: IG.Streamer.Session.Status { get }
    /// Returns a publisher to subscribe to status events.
    ///
    /// This is a multicast publisher, meaning all subscriber will receive the same status in the same order.
    var statusPublisher: AnyPublisher<IG.Streamer.Session.Status,Never> { get }
    ///
    func connect() throws -> IG.Streamer.Session.Status
    /// Subscribe to the following item and field (in the given mode) requesting (or not) a snapshot.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter item: The item identfier (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    /// - returns: A producer providing updates as values. The producer will never complete, it will only be stoped by not holding a reference to the signal or by interrupting it with a disposable.
    #warning("Streamer: Change documentation")
    func subscribe(mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> IG.Streamer.ContinuousPublisher<[String:IG.Streamer.Subscription.Update]>
    /// Unsubscribe to all ongoing subscriptions.
    /// - returns: All currently ongoing subscriptions.
    func unsubscribeAll() -> [IG.Streamer.Subscription]
    ///
    func disconnect() -> IG.Streamer.Session.Status
}
