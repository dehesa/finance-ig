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
    /// Returns a publisher to subscribe to status events (the current value is sent first).
    ///
    /// This publisher remove duplicates (i.e. there aren't any repeating statuses).
    var statusPublisher: AnyPublisher<IG.Streamer.Session.Status,Never> { get }
    /// Tries to connect the low-level client to the server and returns the current client status.
    ///
    /// The connection process takes some time; If the returned status is not `.connected`, then you need to subscribe to the client's statuses and wait for the proper status.
    /// - returns: The client status at the time of the call.
    func connect() throws -> IG.Streamer.Session.Status
    /// Tries to disconnect the low-level client from the server and returns the current client status.
    /// - returns: The client status at the time of the call.
    func disconnect() -> IG.Streamer.Session.Status
    /// Subscribe to the following item and field (in the given mode) requesting (or not) a snapshot.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter item: The item identfier (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    /// - returns: A publisher forwarding updates as values. This publisher will never complete, it will only be stoped by not holding a reference to the signal or by interrupting it with a cancellable.
    func subscribe(mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> IG.Streamer.ContinuousPublisher<[String:IG.Streamer.Subscription.Update]>
    /// Unsubscribe to all ongoing subscriptions.
    /// - returns: All currently ongoing subscriptions.
    func unsubscribeAll() -> [IG.Streamer.Subscription]
}
