import ReactiveSwift
import Foundation

extension Streamer.Request.Session {
    /// Returns the current streamer status.
    public var status: Property<Streamer.Session.Status> {
        return self.streamer.channel.status
    }
    
    /// Connects to the Lightstreamer server specified in the `Streamer` properties.
    ///
    /// If the `Streamer` is already connected, the returning signal will complete immediately.
    /// - returns: Forwards all statuss till it reliably connects to the server (in which case that status is sent and then the signal completes). If it figures out that the connection is impossible, an error is thrown.
    @discardableResult public func connect() -> Signal<Streamer.Session.Status,Streamer.Error> {
        let statusGenerator = self.streamer.channel.status
        guard !statusGenerator.value.isReady else { return .empty }
        
        //let result = self.streamer.channel.status.signal.take(while: { !$0.isReady || $0 == .disconnected(isRetrying: false) })
        defer { self.streamer.channel.connect() }
        
        return  .init { [signal = statusGenerator.signal] (generator, lifetime) in
            lifetime += signal.observe {
                guard case .value(let status) = $0 else { return generator.send($0.promoteError(Streamer.Error.self)) }
                switch status {
                case .connecting, .connected(.sensing), .disconnected(isRetrying: true):
                    generator.send(value: status)
                case .connected(.http), .connected(.websocket):
                    generator.send(value: status)
                    generator.sendCompleted()
                case .disconnected(isRetrying: false), .stalled:
                    generator.send(error: .invalidRequest(message: "A connection to the server couldn't be established. Status: \(status)"))
                }
            }
        }
    }
    
    /// Disconnects to the Lightstreamer server.
    ///
    /// If the `Streamer` is already disconnected, the returning signal will complete immediately.
    /// - returns: Forwards all statuses till it reliably disconnects from the server.
    @discardableResult public func disconnect() -> Signal<Streamer.Session.Status,Streamer.Error> {
        let statusGenerator = self.streamer.channel.status
        if case .disconnected(isRetrying: false) = statusGenerator.value { return .empty }
        
        //let result = self.streamer.channel.status.signal.take(while: { $0 != .disconnected(isRetrying: false) })
        defer { self.streamer.channel.disconnect() }
        
        return .init { [signal = statusGenerator.signal] (generator, lifetime) in
            lifetime += signal.observe {
                guard case .value(let status) = $0 else { return generator.send($0.promoteError(Streamer.Error.self)) }
                
                generator.send(value: status)
                guard case .disconnected(isRetrying: false) = status else { return }
                generator.sendCompleted()
            }
        }
    }
    
    ///
    public func unsubscribeAll() {
        self.streamer.channel.unsubscribeAll()
    }
}

// MARK: - Supporting Entities

extension Streamer.Request {
    /// Contains all functionality related to the Streamer session.
    public struct Session {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        fileprivate unowned let streamer: Streamer
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: Streamer) {
            self.streamer = streamer
        }
    }
}

// MARK: Response Entities

extension Streamer {
    public enum Session {}
}

extension Streamer.Session {
    /// The status at which the streamer can find itself at.
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
        public var isPolling: Bool {
            switch self {
            case .sensing: return false
            case .http(let isPolling): return isPolling
            case .websocket(let isPolling): return isPolling
            }
        }
    }
}

extension Streamer.Session.Status: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .connecting: return "Connecting..."
        case .connected(let connection):
            var result = "Connected"
            switch connection {
            case .sensing:
                result.append(" but sensing medium...")
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
            if (isRetrying) { result.append(" but retrying...") }
            return result
        }
    }
}
