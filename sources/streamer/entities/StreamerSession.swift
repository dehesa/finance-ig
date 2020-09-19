import Foundation

extension Streamer {
    public enum Session {}
}

extension Streamer.Session {
    /// The connection status.
    public enum Status: Equatable {
        /// A connection has been attempted. The client is waiting for a server answer.
        case connecting
        /// The client and server are connected.
        case connected(Self.Connection)
        /// A streaming session has been silent for a while.
        case stalled
        /// The client and server are disconnected.
        case disconnected(isRetrying: Bool)
        
        /// Boolean indicating a ready-to-receive-data status.
        /// - returns: `true` only when a connection is fully established (i.e. connection sensing is NOT considered "fully connected").
        @_transparent public var isReady: Bool {
            switch self {
            case .connected(.http), .connected(.websocket): return true
            default: return false
            }
        }
        
        /// Boolean indicating a `.connecting` and `.connected(.sensing)` statuses.
        @_transparent public var isConnecting: Bool {
            switch self {
            case .connecting, .connected(.sensing): return true
            default: return false
            }
        }
    }
}

extension Streamer.Session.Status {
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
        @_transparent public var isPolling: Bool {
            switch self {
            case .sensing: return false
            case .http(let isPolling): return isPolling
            case .websocket(let isPolling): return isPolling
            }
        }
    }
}

// MARK: -

extension Streamer.Session.Status: RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case _Values.connecting: self = .connecting
        case _Values.connectedSensing: self = .connected(.sensing)
        case _Values.connectedWebSocketStream: self = .connected(.websocket(isPolling: false))
        case _Values.connectedWebSocketPoll: self = .connected(.websocket(isPolling: true))
        case _Values.connectedHTTPStream: self = .connected(.http(isPolling: false))
        case _Values.connectedHTTPPoll: self = .connected(.http(isPolling: true))
        case _Values.stalled: self = .stalled
        case _Values.disconnectedRetrying: self = .disconnected(isRetrying: true)
        case _Values.disconnectedNoRetry: self = .disconnected(isRetrying: false)
        default: return nil
        }
    }
    
    public var rawValue: String {
        switch self {
        case .connecting: return _Values.connecting
        case .connected(let connection):
            switch connection {
            case .sensing: return _Values.connectedSensing
            case .websocket(let isPolling): return (!isPolling) ? _Values.connectedWebSocketStream : _Values.connectedWebSocketPoll
            case .http(let isPolling): return (!isPolling) ? _Values.connectedHTTPStream : _Values.connectedHTTPPoll
            }
        case .stalled: return _Values.stalled
        case .disconnected(let isRetrying): return (!isRetrying) ? _Values.disconnectedNoRetry : _Values.disconnectedRetrying
        }
    }
    
    /// State representation as the Lightstreamer needs it.
    private enum _Values {
        static var connecting: String { "CONNECTING" }
        static var connectedSensing: String { "CONNECTED:STREAM-SENSING" }
        static var connectedWebSocketStream: String { "CONNECTED:WS-STREAMING" }
        static var connectedWebSocketPoll: String { "CONNECTED:WS-POLLING" }
        static var connectedHTTPStream: String { "CONNECTED:HTTP-STREAMING" }
        static var connectedHTTPPoll: String { "CONNECTED:HTTP-POLLING" }
        static var stalled: String { "STALLED" }
        static var disconnectedRetrying: String { "DISCONNECTED:WILL-RETRY" }
        static var disconnectedNoRetry: String { "DISCONNECTED" }
    }
}
