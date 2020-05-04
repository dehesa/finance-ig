import Conbini
import Combine
import Foundation

extension IG.Streamer.Request {
    /// Contains all functionality related to the Streamer session.
    public struct Session {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        fileprivate unowned let _streamer: IG.Streamer
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: IG.Streamer) { self._streamer = streamer }
    }
}

extension IG.Streamer.Request.Session {
    /// The credentials being currently used on this streamer.
    public var credentials: IG.Streamer.Credentials {
        self._streamer.channel.credentials
    }
    
    /// Returns the current streamer status (e.g. whether connecting, connected, disconnected, etc.).
    public var status: IG.Streamer.Session.Status {
        self._streamer.channel.status
    }
    
    /// Returns a publisher to subscribe to the streamer's statuses.
    /// - remark: The subject never fails and only completes successfully when the `Channel` gets deinitialized.
    /// - returns: Publisher emitting unique status values and only completing (successfully) when the `API` instance is deinitialized.
    public var statusStream: AnyPublisher<IG.Streamer.Session.Status,Never> {
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
    public func connect() -> AnyPublisher<IG.Streamer.Session.Status,IG.Streamer.Error> {
        // 1. Subscribe to the channel statuses.
        return self._streamer.channel.statusStream(on: self._streamer.queue)
            .setFailureType(to: Swift.Error.self)
            // 2. If the status stream completes, it means the streamer got deinitialized, and therefore the connection failed.
            .append( Fail(error: IG.Streamer.Error.sessionExpired() as Swift.Error) )
            // 3. Only connect to the channel, when a subscription has been made.
            .prepend( Deferred { [weak weakStreamer = self._streamer] in
                Result.Publisher( Result {
                    guard let streamer = weakStreamer else { throw IG.Streamer.Error.sessionExpired() }
                    let status = try streamer.channel.connect()
                    return (status == .disconnected(isRetrying: false)) ? .connecting : status
                } )
            // 4. Filter the _connecting_ statuses.
            }).tryFirst(where: {
                switch $0 {
                case .connected(.http), .connected(.websocket): return true
                case .connected(.sensing), .connecting, .disconnected(isRetrying: true): return false
                case .disconnected(isRetrying: false): throw IG.Streamer.Error(.invalidResponse, "The connection to the server couldn't be established", suggestion: "Check there is connection and try again.")
                case .stalled: throw IG.Streamer.Error(.invalidResponse, "There is a connection established with the server, but it seems to be stalled", suggestion: "Manually disconnect and try again.")
                }
            }).mapError { $0 as! IG.Streamer.Error }
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
    public func disconnect() -> AnyPublisher<IG.Streamer.Session.Status,Never> {
        // 1. Subscribe to the channel status.
        self._streamer.channel.statusStream(on: self._streamer.queue)
            .prepend( Deferred { [weak weakStreamer = self._streamer] () -> Just<IG.Streamer.Session.Status> in
                let status: IG.Streamer.Session.Status
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

// MARK: - Entities

extension IG.Streamer {
    public enum Session {}
}

extension IG.Streamer.Session {
    /// The connection status.
    public enum Status: RawRepresentable, Equatable {
        /// A connection has been attempted. The client is waiting for a server answer.
        case connecting
        /// The client and server are connected.
        case connected(Self.Connection)
        /// A streaming session has been silent for a while.
        case stalled
        /// The client and server are disconnected.
        case disconnected(isRetrying: Bool)
        
        public init?(rawValue: String) {
            switch rawValue {
            case _Key.connecting.rawValue: self = .connecting
            case _Key.connectedSensing.rawValue: self = .connected(.sensing)
            case _Key.connectedWebSocketStream.rawValue: self = .connected(.websocket(isPolling: false))
            case _Key.connectedWebSocketPoll.rawValue: self = .connected(.websocket(isPolling: true))
            case _Key.connectedHTTPStream.rawValue: self = .connected(.http(isPolling: false))
            case _Key.connectedHTTPPoll.rawValue: self = .connected(.http(isPolling: true))
            case _Key.stalled.rawValue: self = .stalled
            case _Key.disconnectedRetrying.rawValue: self = .disconnected(isRetrying: true)
            case _Key.disconnectedNoRetry.rawValue: self = .disconnected(isRetrying: false)
            default: return nil
            }
        }
        
        public var rawValue: String {
            switch self {
            case .connecting: return _Key.connecting.rawValue
            case .connected(let connection):
                switch connection {
                case .sensing: return _Key.connectedSensing.rawValue
                case .websocket(let isPolling): return (!isPolling) ? _Key.connectedWebSocketStream.rawValue : _Key.connectedWebSocketPoll.rawValue
                case .http(let isPolling): return (!isPolling) ? _Key.connectedHTTPStream.rawValue : _Key.connectedHTTPPoll.rawValue
                }
            case .stalled: return _Key.stalled.rawValue
            case .disconnected(let isRetrying): return (!isRetrying) ? _Key.disconnectedNoRetry.rawValue : _Key.disconnectedRetrying.rawValue
            }
        }
        
        /// Boolean indicating a ready-to-receive-data status.
        /// - returns: `true` only when a connection is fully established (i.e. connection sensing is NOT considered "fully connected").
        public var isReady: Bool {
            switch self {
            case .connected(.http), .connected(.websocket): return true
            default: return false
            }
        }
        
        /// Boolean indicating a `.connecting` and `.connected(.sensing)` statuses.
        public var isConnecting: Bool {
            switch self {
            case .connecting, .connected(.sensing): return true
            default: return false
            }
        }
        
        /// State representation as the Lightstreamer needs it.
        private enum _Key: String {
            case connecting = "CONNECTING"
            case connectedSensing = "CONNECTED:STREAM-SENSING"
            case connectedWebSocketStream = "CONNECTED:WS-STREAMING"
            case connectedWebSocketPoll = "CONNECTED:WS-POLLING"
            case connectedHTTPStream = "CONNECTED:HTTP-STREAMING"
            case connectedHTTPPoll = "CONNECTED:HTTP-POLLING"
            case stalled = "STALLED"
            case disconnectedRetrying = "DISCONNECTED:WILL-RETRY"
            case disconnectedNoRetry = "DISCONNECTED"
        }
    }
}

extension IG.Streamer.Session.Status {
    /// The type of connection established between the client and server.
    public enum Connection: Equatable {
        /// The client has received a first response from the server and is evaluating if a streaming connection can be established.
        case sensing
        /// Connection over HTTP.
        ///
        /// When `isPolling` is set to `false`, a streaming connection is in place. On the other hand, a *polling* connection is established.
        case http(isPolling: Bool)
        /// Connection over WebSocket.
        ///
        /// When `isPolling` is set to `false`, a streaming connection is in place. On the other hand, a *polling* connection is established.
        case websocket(isPolling: Bool)
        
        /// Boolean indicating whether the connection is polling the server (undesirable) or streaming.
        ///
        /// Streaming connections are better and more responsive than polling connection.
        public var isPolling: Bool {
            switch self {
            case .sensing: return false
            case .http(let isPolling): return isPolling
            case .websocket(let isPolling): return isPolling
            }
        }
    }
}

extension IG.Streamer.Session.Status: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .connecting: return "Connecting"
        case .connected(let connection):
            var (result, isPolling) = ("Connected ", false)
            switch connection {
            case .sensing:
                result.append("(sensing)")
                return result
            case .websocket(let polling):
                result.append("[WebSocket")
                isPolling = polling
            case .http(let polling):
                result.append("[HTTP")
                isPolling = polling
            }
            if (isPolling) {
                result.append(" polling]")
            } else {
                result.append(" stream]")
            }
            return result
        case .stalled:    return "Stalled!"
        case .disconnected(let isRetrying):
            var result = "Disconnected"
            if (isRetrying) {
                result.append(" (retrying)")
            }
            return result
        }
    }
}
