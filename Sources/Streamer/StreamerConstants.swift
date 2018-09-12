import Foundation

extension Streamer {
    /// The status at which the streamer can find itself at.
    public enum Status: RawRepresentable, Equatable, CustomDebugStringConvertible {
        /// A connection has been attempted. The client is waiting for a server answer.
        case connecting
        /// The client and server are connected.
        case connected(Connection)
        /// A streaming session has been silent for a while.
        case stalled
        /// The client and server are disconnected.
        case disconnected(isRetrying: Bool)
        
        /// The type of connection established between the client and server.
        public enum Connection: Equatable {
            /// Connection over WebSocket.
            case websocket(isPolling: Bool)
            /// Connection over HTTP.
            case http(isPolling: Bool)
            /// The client has received a first response from the server and is not evaluating if a streaming connection is fully functional.
            case sensing
            
            /// Boolean indicating whether the connection is polling the server (undesirable) or streaming.
            ///
            /// Streaming connections are better and more responsive than polling connection.
            public var isPolling: Bool {
                switch self {
                case .websocket(let isPolling): return isPolling
                case .http(let isPolling): return isPolling
                case .sensing: return false
                }
            }
            
            public static func == (lhs: Connection, rhs: Connection) -> Bool {
                switch (lhs, rhs) {
                case (.websocket(let a), .websocket(let b)): return a == b
                case (.http(let a), .http(let b)): return a == b
                case (.sensing, .sensing): return true
                default: return false
                }
            }
        }
        
        public init?(rawValue: String) {
            switch rawValue {
            case Key.connecting.rawValue: self = .connecting
            case Key.connectedSensing.rawValue: self = .connected(.sensing)
            case Key.connectedWebSocketStream.rawValue: self = .connected(.websocket(isPolling: false))
            case Key.connectedWebSocketPoll.rawValue: self = .connected(.websocket(isPolling: true))
            case Key.connectedHTTPStream.rawValue: self = .connected(.http(isPolling: true))
            case Key.connectedHTTPPoll.rawValue: self = .connected(.http(isPolling: true))
            case Key.stalled.rawValue: self = .stalled
            case Key.disconnectedRetrying.rawValue: self = .disconnected(isRetrying: true)
            case Key.disconnectedNoRetry.rawValue: self = .disconnected(isRetrying: false)
            default: return nil
            }
        }
        
        public var rawValue: String {
            switch self {
            case .connecting: return Key.connecting.rawValue
            case .connected(let connection):
                switch connection {
                case .sensing: return Key.connectedSensing.rawValue
                case .websocket(let isPolling): return (!isPolling) ? Key.connectedWebSocketStream.rawValue : Key.connectedWebSocketPoll.rawValue
                case .http(let isPolling): return (!isPolling) ? Key.connectedHTTPStream.rawValue : Key.connectedHTTPPoll.rawValue
                }
            case .stalled: return Key.stalled.rawValue
            case .disconnected(let isRetrying): return (!isRetrying) ? Key.disconnectedNoRetry.rawValue : Key.disconnectedRetrying.rawValue
            }
        }
        
        public static func == (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.connecting, .connecting), (.stalled, .stalled): return true
            case (.connected(let a), .connected(let b)): return a == b
            case (.disconnected(let a), .disconnected(let b)): return a == b
            default: return false
            }
        }
        
        public var debugDescription: String {
            switch self {
            case .connecting: return "Connecting..."
            case .connected(let connection):
                var result = "Connected"
                switch connection {
                case .sensing:
                    result.append(" (sensing medium...)")
                case .websocket(let isPolling):
                    result.append(" (WebSocket")
                    if (isPolling) { result.append(" polling)") }
                    else { result.append(" stream)") }
                case .http(let isPolling):
                    result.append(" (HTTP")
                    if (isPolling) { result.append(" polling)") }
                    else { result.append(" stream)") }
                }
                return result
            case .stalled:    return "Stalled!"
            case .disconnected(let isRetrying):
                var result = "Disconnected"
                if (isRetrying) { result.append(" (retrying...)") }
                return result
            }
        }
        
        /// State representation as the Lightstreamer needs it.
        private enum Key: String {
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

    /// Possible Lightstreamer modes.
    internal enum Mode: String {
        /// Lightstreamer MERGE mode.
        case merge = "MERGE"
        /// Lightstreamer DISTINCT mode.
        case distinct = "DISTINCT"
        /// Lightstreamer RAW mode.
        case raw = "RAW"
        /// Lightstreamer COMMAND mode.
        case command = "COMMAND"
    }
}
