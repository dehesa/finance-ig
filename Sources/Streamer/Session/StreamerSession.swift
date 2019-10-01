import Combine
import Foundation

extension IG.Streamer.Request {
    /// Contains all functionality related to the Streamer session.
    public struct Session {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        fileprivate unowned let streamer: IG.Streamer
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: IG.Streamer) {
            self.streamer = streamer
        }
    }
}

extension IG.Streamer.Request.Session {
    /// Returns the current streamer status.
    public var status: IG.Streamer.Session.Status {
        self.streamer.channel.status
    }
    
    /// Returns a publisher to subscribe to the streamer's statuses.
    ///
    /// This is a multicast publisher, meaning all subscriber will receive the same status in the same order.
    public var statusPublisher: AnyPublisher<IG.Streamer.Session.Status,Never> {
        self.streamer.channel.statusPublisher
    }
    
    /// Connects to the Lightstreamer server specified in the `Streamer` properties.
    ///
    /// - If the `Streamer` is already connected, then the connected status is forward and the publisher completes immediately.
    /// - If the `Streamer` is already *connecting*, the events from that publisher are forwarded here and the `timeout` paramter is ignored (in favor of the previously set one).
    ///
    /// - parameter timeout: The maximum waiting for connection time before an error is sent.
    /// - returns: Forwards all statuses till it reliably connects to the server (in which case that status is sent and then the publisher completes). If the connection is not possible, there is a timeout, or the session has expired, an error is thrown.
    public func connect(timeout: DispatchTimeInterval = .seconds(4)) -> IG.Streamer.ContinuousPublisher<IG.Streamer.Session.Status> {
        Future<IG.Streamer.ContinuousPublisher<IG.Streamer.Session.Status>,IG.Streamer.Error> { [weak weakStreamer = self.streamer] (promise) in
                guard let streamer = weakStreamer else {
                    return promise(.failure(.sessionExpired()))
                }
                
                let initialStatus: IG.Streamer.Session.Status
                do {
                    initialStatus = try streamer.channel.connect()
                } catch let error {
                    return promise(.failure(.transform(error)))
                }
            
                if initialStatus.isReady {
                    let result = Just<IG.Streamer.Session.Status>(initialStatus)
                        .setFailureType(to: IG.Streamer.Error.self)
                        .eraseToAnyPublisher()
                    return promise(.success(result))
                }
                
                var forwardStatus = initialStatus != .disconnected(isRetrying: false)
                var cancellable: AnyCancellable? = nil
            
                let subject = PassthroughSubject<IG.Streamer.Session.Status,IG.Streamer.Error>()
                cancellable = streamer.channel.statusPublisher.sink { [weak weakSubject = subject] in
                    if let generator = weakSubject {
                        generator.send($0)
                        
                        switch $0 {
                        case .connected(.sensing), .connecting, .disconnected(isRetrying: true):
                            forwardStatus = true; return
                        case .connected(.http), .connected(.websocket):
                            generator.send(completion: .finished)
                        case .stalled:
                            let message = "There is a connection established with the server, but it seems to be stalled"
                            let suggestion = "Check there is connection and try again."
                            generator.send(completion: .failure(.init(.invalidResponse, .init(message), suggestion: .init(suggestion))))
                        case .disconnected(isRetrying: false):
                            guard forwardStatus else { forwardStatus = true; return }
                            let message = "The connection to the server couldn't be established"
                            let suggestion = "Check there is connection and try again."
                            generator.send(completion: .failure(.init(.invalidResponse, .init(message), suggestion: .init(suggestion))))
                        }
                    }
                    
                    cancellable?.cancel()
                    cancellable = nil
                }
            
                return promise(.success(subject.eraseToAnyPublisher()))
        }.flatMap(maxPublishers: .max(1), { (publisher) in
            publisher
        }).eraseToAnyPublisher()
    }
    
    /// Disconnects to the Lightstreamer server.
    ///
    /// - If the `Streamer` is already disconnected, then the connected status is forward and the publisher completes immediately.
    /// - If the `Streamer` is already is a connection process, the events from that publisher are forwarded here.
    ///
    /// - returns: Forwards all statuses till it reliably disconnects from the server (in which case the status is sent and then the signal completes). If the connection is not possible or the session has expired, an error is thrown.
//    public func disconnect() -> IG.Streamer.ContinuousPublisher<IG.Streamer.Session.Status> {
//        Future<IG.Streamer.ContinuousPublisher<IG.Streamer.Session.Status>,IG.Streamer.Error> { [weak weakStreamer = self.streamer] (promise) in
//                guard let streamer = weakStreamer else {
//                    return promise(.failure(.sessionExpired()))
//                }
//
//                promise(.success(streamer.channel.disconnect()))
//            }.switchToLatest().eraseToAnyPublisher()
//    }
    
    /// Unsubscribes from all ongoing subscriptions.
    ///
    /// This method forwards the following events:
    /// - string values representing the subscription items that have been successfully unsubscribed.
    /// - Send an error if any of the unsubscription encounter any error (but only at the end of the subscription process).
    /// - Send a complete event once everything is unsubscribed.
    /// - returns: Forwards all "items" that have been successfully unsubscribed, till there are no more, in which case it sends a *complete* event.
//    public func unsubscribeAll() -> SignalProducer<String,IG.Streamer.Error> {
//        return .init { [weak streamer = self.streamer] (generator, lifetime) in
//            guard let streamer = streamer else { return generator.send(error: .sessionExpired()) }
//
//            unowned let channel = streamer.channel
//            let iterator: [Self.UnsubWrapper] = channel.unsubscribeAll().map { .init($0) }
//            guard !iterator.isEmpty else { return generator.sendCompleted() }
//
//            var storage: Set<Self.UnsubWrapper> = .init(iterator)
//            var errors: [IG.Streamer.Error] = []
//
//            for wrapper in iterator {
//                // Start listening to every single subscription status changes
//                wrapper.detacher = lifetime += wrapper.subscription.status.producer.start { (event) in
//                    switch event {
//                    case .value(let status):
//                        switch status {
//                        case .subscribed, .updateReceived, .updateLost:
//                            return
//                        case .unsubscribed:
//                            storage.remove(wrapper)
//                            generator.send(value: wrapper.subscription.item)
//                        case .error(let underlyingError):
//                            storage.remove(wrapper)
//                            let message = "An unknown problem occurred when unsubscribing"
//                            let suggestion = "No problems should stam from this; however, if it happens frequently please contact the repository maintainer"
//                            let error: IG.Streamer.Error = .subscriptionFailed(message, item: wrapper.subscription.item, fields: wrapper.subscription.fields, underlying: underlyingError, suggestion: suggestion)
//                            errors.append(error)
//                        }
//                    case .completed: // The producer shall only complete when the channel is deinitialized
//                        storage.remove(wrapper)
//                        errors.append(.sessionExpired())
//                    case .interrupted: // The producer shall only be interrupted by stopping the result signal's lifetime
//                        return
//                    case .failed: // The producer shall never fail
//                        fatalError("A subscription status provide cannot fail")
//                    }
//
//                    wrapper.detacher?.dispose()
//                    guard storage.isEmpty else { return }
//
//                    if errors.isEmpty {
//                        return generator.sendCompleted()
//
//                    } else {
//                        let message = "\(errors.count) were encountered when trying to unsubscribe all current \(IG.Streamer.self) subscriptions"
//                        let suggestion = "No problems should stam from this; however, if it happens frequently please contact the repository maintainer"
//                        var error: IG.Streamer.Error = .init(.subscriptionFailed, message, suggestion: suggestion)
//                        error.context.append(("Unsubscription errors", errors))
//                        return generator.send(error: error)
//                    }
//                }
//            }
//        }
//    }
}

// MARK: - Entities
#warning("Streamer: Uncomment")
//extension IG.Streamer.Request.Session {
//    /// Wrapper for the unsubscription process.
//    fileprivate final class UnsubWrapper: Hashable {
//        /// The instance gathering the subscription data (including the underlying Lighstreamer subscription).
//        let subscription: IG.Streamer.Subscription
//        /// Disposable to stop listening for the subscription status.
//        var detacher: Disposable?
//
//        init(_ subscription: IG.Streamer.Subscription) {
//            self.subscription = subscription
//            self.detacher = nil
//        }
//
//        func hash(into hasher: inout Hasher) {
//            hasher.combine(self.subscription)
//        }
//
//        static func == (lhs: IG.Streamer.Request.Session.UnsubWrapper, rhs: IG.Streamer.Request.Session.UnsubWrapper) -> Bool {
//            return lhs.subscription == rhs.subscription
//        }
//    }
//}

extension IG.Streamer {
    public enum Session {}
}

extension IG.Streamer.Session {
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
