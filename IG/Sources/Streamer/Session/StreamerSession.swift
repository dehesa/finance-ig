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
    
    /// Returns a publisher to subscribe to the streamer's statuses.
    ///
    /// The subject behind this function is a `CurrentValueSubject`, which means on subscription you will receive the current value.
    /// - returns: Publisher emitting unique status values and only completing (successfully) when the `API` instance is deinitialized. 
    public func status() -> AnyPublisher<IG.Streamer.Session.Status,Never> {
        self._streamer.channel.subscribeToStatus(on: self._streamer.queue).eraseToAnyPublisher()
    }
    
    /// Connects to the Lightstreamer server specified in the `Streamer` properties.
    ///
    /// If the `Streamer` is already connected, then the *connected* status is forwarded and the publisher completes immediately.
    /// - returns: Forwards all statuses till it reliably connects to the server (in which case that status is sent and then the publisher completes). If the connection is not possible, an error is thrown.
    public func connect() -> AnyPublisher<IG.Streamer.Session.Status,IG.Streamer.Error> {
        /// Keep the necessary state to clean up the *slate* once the publisher finishes or it is cancelled.
        var cancellable: Cancellable? = nil
        /// When triggered, it stops the status monitoring and forwarding.
        let cleanUp: ()->Void = { cancellable?.cancel(); cancellable = nil }
        
        return DeferredPassthrough<IG.Streamer.Session.Status,IG.Streamer.Error> { [weak weakStreamer = self._streamer] (subject) in
            guard let streamer = weakStreamer else {
                return subject.send(completion: .failure(.sessionExpired()))
            }
            
            let sink = Subscribers.Sink<IG.Streamer.Session.Status,Never>(receiveCompletion: { [weak subject] _ in
                subject?.send(completion: .finished)
            }, receiveValue: { [weak subject] (status) in
                subject?.send(status)
                
                switch status {
                case .connected(.sensing), .connecting, .disconnected(isRetrying: true):
                    break
                case .connected(.http), .connected(.websocket):
                    subject?.send(completion: .finished)
                case .stalled:
                    let error = IG.Streamer.Error(.invalidResponse, "There is a connection established with the server, but it seems to be stalled", suggestion: "Manually disconnect and try again.")
                    subject?.send(completion: .failure(error))
                case .disconnected(isRetrying: false):
                    let error = IG.Streamer.Error(.invalidResponse, "The connection to the server couldn't be established", suggestion: "Check there is connection and try again.")
                    subject?.send(completion: .failure(error))
                }
            })
            
            cancellable = sink
            streamer.channel.subscribeToStatus(on: streamer.queue)
                .drop(while: { $0 == .disconnected(isRetrying: false) })
                .subscribe(sink)
            _ = try? streamer.channel.connect()
            
        }.handleEvents(receiveCompletion: { _ in cleanUp() }, receiveCancel: cleanUp)
        .receive(on: self._streamer.queue)
        .eraseToAnyPublisher()
    }
    
    /// Disconnects to the Lightstreamer server.
    ///
    /// If the `Streamer` is already disconnected, then the disconnected status is forwarded and the publisher completes immediately.
    /// - remark: This function also unsubscribe any ongoing subscription (i.e. cancels the subscription publishers).
    /// - returns: Forwards all statuses till it reliably disconnects from the server (in which case the status is sent and then the publisher completes). If the connection is not possible or the session has expired, an error is thrown.
    public func disconnect() -> AnyPublisher<IG.Streamer.Session.Status,Never> {
        /// Keep the necessary state to clean up the *slate* once the publisher finishes or it is cancelled.
        var cancellable: Cancellable? = nil
        /// When triggered, it stops the status monitoring and forwarding.
        let cleanUp: ()->Void = { cancellable?.cancel(); cancellable = nil }
        
        return DeferredPassthrough<IG.Streamer.Session.Status,Never> { [weak weakStreamer = self._streamer] (subject) in
            guard let streamer = weakStreamer else {
                return subject.send(completion: .finished)
            }
            
            let sink = Subscribers.Sink<IG.Streamer.Session.Status,Never>(receiveCompletion: { [weak subject] _ in
                subject?.send(completion: .finished)
            }, receiveValue: { [weak subject] (status) in
                subject?.send(status)
                guard case .disconnected(isRetrying: false) = status else { return }
                subject?.send(completion: .finished)
            })
            
            cancellable = sink
            streamer.channel.unsubscribeAll()
            streamer.channel.subscribeToStatus(on: streamer.queue)
                .subscribe(sink)
            streamer.channel.disconnect()
        }.handleEvents(receiveCompletion: { _ in cleanUp() }, receiveCancel: cleanUp)
        .receive(on: self._streamer.queue)
        .eraseToAnyPublisher()
    }
    
    /// Unsubscribes from all ongoing subscriptions.
    ///
    /// This publisher forwards the following events:
    /// - `String` values representing the subscription items that have been successfully unsubscribed.
    /// - sends an error if any of the unsubscription encounter any error (but only at the end of the subscription process). That is, the error is stored and thrown when all subscription messages has been sent.
    /// - sends a complete event once everything is unsubscribed.
    ///
    /// - returns: Forwards all "items" that have been successfully unsubscribed, till there are no more, in which case it sends a *complete* event.
    /// - todo: Figure out a way to communicate the ongoing unsubscriptions. Currently the implementation supposes unsubscription is immediate (which most times it is).
    public func unsubscribeAll() -> AnyPublisher<String,IG.Streamer.Error> {
        DeferredResult { [weak streamer = self._streamer] () -> Result<IG.Streamer,IG.Streamer.Error> in
            guard let streamer = streamer else {
                return .failure(.sessionExpired())
            }
            return .success(streamer)
        }.flatMap { (streamer) in
            streamer.channel.unsubscribeAll()
                .publisher
                .setFailureType(to: IG.Streamer.Error.self)
        }.eraseToAnyPublisher()
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
