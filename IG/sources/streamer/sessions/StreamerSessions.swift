import Conbini
import Combine
import Foundation

extension Streamer.Request {
    /// Contains all functionality related to the Streamer session.
    public struct Session {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        fileprivate unowned let _streamer: Streamer
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        @usableFromInline internal init(streamer: Streamer) { self._streamer = streamer }
    }
}

extension Streamer.Request.Session {
    /// The credentials being currently used on this streamer.
    public var credentials: Streamer.Credentials {
        self._streamer.channel.credentials
    }
    
    /// Returns the current streamer status (e.g. whether connecting, connected, disconnected, etc.).
    public var status: Streamer.Session.Status {
        self._streamer.channel.status
    }
    
    /// Returns a publisher to subscribe to the streamer's statuses.
    /// - remark: The subject never fails and only completes successfully when the `Channel` gets deinitialized.
    /// - returns: Publisher emitting unique status values and only completing (successfully) when the `API` instance is deinitialized.
    public var statusStream: AnyPublisher<Streamer.Session.Status,Never> {
        self._streamer.channel.statusStream(on: self._streamer.queue)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Connects to the Lightstreamer server specified in the `Streamer` properties.
    ///
    /// If the `Streamer` is already connected, then the *connected* status is forwarded and the publisher completes immediately.
    ///
    /// There is no timeout for this operation, if you want one, you should append the `timeout` operator. Also, if you want to disconnect the streamer on cancel, you need to add that operator yourself.
    /// - remark: If the holding streamer instance gets deinitialized, the returned publisher gets cancelled (no completion event is emitted).
    /// - returns: Forwards the connected status and then completes. If the connection isn't possible, an error is emitted.
    public func connect() -> AnyPublisher<Streamer.Session.Status,IG.Error> {
        // 1. Subscribe to the channel statuses.
        return self._streamer.channel.statusStream(on: self._streamer.queue)
            .setFailureType(to: Swift.Error.self)
            // 2. If the status stream completes, it means the streamer got deinitialized, and therefore the connection failed.
            .append( Fail(error: IG.Error._deallocatedInstance() as Swift.Error) )
            // 3. Only connect to the channel, when a subscription has been made.
            .prepend( Deferred { [weak weakStreamer = self._streamer] in
                Result.Publisher( Result {
                    guard let streamer = weakStreamer else { throw IG.Error._deallocatedInstance() }
                    let status = try streamer.channel.connect()
                    return (status == .disconnected(isRetrying: false)) ? .connecting : status
                } )
            // 4. Filter the _connecting_ statuses.
            }).tryFirst(where: {
                switch $0 {
                case .connected(.http), .connected(.websocket): return true
                case .connected(.sensing), .connecting, .disconnected(isRetrying: true): return false
                case .disconnected(isRetrying: false): throw IG.Error._unableToConnect()
                case .stalled: throw IG.Error._stalledConnection()
                }
            }).mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Unsubscribes from all ongoing subscriptions.
    public func unsubscribeAll() {
        self._streamer.channel.unsubscribeAll()
    }
    
    /// Disconnects to the Lightstreamer server. This function also unsubscribes any ongoing subscription (i.e. cancels the subscription publishers).
    ///
    /// If the `Streamer` is already disconnected, then the disconnected status is forwarded and the publisher completes immediately.
    ///
    /// There is no timeout for this operation, if you want one, you should append the `timeout` operator.
    /// - remark: If the holding streamer instance gets deinitialized, the returned publisher gets cancelled (no completion event is emitted).
    /// - returns: Forwards the disconnected status and then completes. If the connection isn't possible, an error is emitted.
    public func disconnect() -> AnyPublisher<Streamer.Session.Status,Never> {
        // 1. Subscribe to the channel status.
        self._streamer.channel.statusStream(on: self._streamer.queue)
            .prepend( Deferred { [weak weakStreamer = self._streamer] () -> Just<Streamer.Session.Status> in
                let status: Streamer.Session.Status
                // 2. Unsubscribe all if needed and disconnect.
                if let channel = weakStreamer?.channel {
                    channel.unsubscribeAll()
                    status = channel.disconnect()
                } else {
                    status = .disconnected(isRetrying: false)
                }
                return Just(status)
            // 3. Wait for the disconnect message and then finish.
            }).first(where: { $0 == .disconnected(isRetrying: false) })
            .eraseToAnyPublisher()
    }
}

private extension IG.Error {
    /// Error raised when the Streamer instance is deallocated.
    static func _deallocatedInstance() -> Self {
        Self(.streamer(.sessionExpired), "The \(Streamer.self) instance has been deallocated.", help: "The API functionality is asynchronous. Keep around the API instance while the request/response is being processed.")
    }
    /// Error raised when the connection to the server cannot be established.
    static func _unableToConnect() -> Self {
        Self(.streamer(.invalidResponse), "The connection to the server couldn't be established.", help: "Check there is connection and try again.")
    }
    /// Error raised when the server connection is stalled.
    static func _stalledConnection() -> Self {
        Self(.streamer(.invalidResponse), "There is a connection established with the server, but it seems to be stalled.", help: "Manually disconnect and try again.")
    }
}
