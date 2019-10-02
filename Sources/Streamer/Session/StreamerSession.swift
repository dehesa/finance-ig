import Combine
import Foundation

struct PassthroughPublisher<Output,Failure:Error>: Publisher {
    typealias Closure = (PassthroughSubject<Output,Failure>) -> Void
    private let closure: Closure
    
    init(_ setup: @escaping Closure) {
        self.closure = setup
    }
    
    func receive<S>(subscriber: S) where S:Subscriber, Failure==S.Failure, Output==S.Input {
        let subject = PassthroughSubject<Output,Failure>()
        let subscription = Conduit(subject: subject, downstream: subscriber, closure: self.closure)
        subject.receive(subscriber: subscription)
    }
    
    private final class Conduit<Downstream>: Subscription, Subscriber where Downstream: Subscriber, Failure==Downstream.Failure, Output==Downstream.Input {
        var upstream: (subscription: Subscription?, subject: PassthroughSubject<Output,Failure>)?
        private var downstream: Downstream?
        private var closure: Closure?
        
        init(subject: PassthroughSubject<Output,Failure>, downstream: Downstream, closure: @escaping Closure) {
            self.downstream = downstream
            self.upstream = (nil, subject)
            self.closure = closure
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard let upstream = self.upstream else { return }
            upstream.subscription!.request(demand)
            
            guard let closure = self.closure, demand > .none else { return }
            self.closure = nil
            closure(upstream.subject)
        }
        
        func cancel() {
            self.closure = nil
            self.downstream = nil
            if let upstream = self.upstream {
                upstream.subscription?.cancel()
                self.upstream = nil
            }
        }
        
        func receive(subscription: Subscription) {
            guard let _ = self.upstream,
                  let downstream = self.downstream else {
                return self.cancel()
            }
            self.upstream?.subscription = subscription
            downstream.receive(subscription: self)
        }
        
        func receive(_ input: Output) -> Subscribers.Demand {
            guard let downstream = self.downstream else {
                self.cancel(); return .none
            }
            return downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            self.closure = nil
            if let downstream = downstream {
                self.downstream = nil
                downstream.receive(completion: completion)
            }
            self.upstream = nil
        }
    }
}

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
        /// The type of publisher passed by the future.
        typealias ConnectionPublisher = IG.Streamer.ContinuousPublisher<IG.Streamer.Session.Status>

        var cancellable: AnyCancellable? = nil
        let cleanup: ()->Void = {
            cancellable?.cancel()
            cancellable = nil
        }
        
        return Future<ConnectionPublisher,IG.Streamer.Error> { [weak weakStreamer = self.streamer] (promise) in
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
                
                let subject = PassthroughSubject<IG.Streamer.Session.Status,IG.Streamer.Error>()
            
                var receivedFirstStatus = false
                cancellable = streamer.channel.statusPublisher.drop {
                    guard !receivedFirstStatus else { return false }
                    receivedFirstStatus = true
                    
                    guard initialStatus == .disconnected(isRetrying: false) else { return false }
                    return $0 == .disconnected(isRetrying: false)
                }.sink { [weak weakSubject = subject] in
                    guard let subject = weakSubject else { return }
                    subject.send($0)
                    
                    switch $0 {
                    case .connected(.sensing), .connecting, .disconnected(isRetrying: true):
                        break
                    case .connected(.http), .connected(.websocket):
                        subject.send(completion: .finished)
                    case .stalled:
                        let message = "There is a connection established with the server, but it seems to be stalled"
                        let suggestion = "Check there is connection and try again."
                        subject.send(completion: .failure(.init(.invalidResponse, .init(message), suggestion: .init(suggestion))))
                    case .disconnected(isRetrying: false):
                        let message = "The connection to the server couldn't be established"
                        let suggestion = "Check there is connection and try again."
                        subject.send(completion: .failure(.init(.invalidResponse, .init(message), suggestion: .init(suggestion))))
                    }
                }
            
                return promise(.success(subject.eraseToAnyPublisher()))
            }.flatMap(maxPublishers: .max(1)) { $0 }
            .handleEvents(receiveCompletion: { (_) in cleanup() }, receiveCancel: cleanup)
            .eraseToAnyPublisher()
    }
    
    /// Disconnects to the Lightstreamer server.
    ///
    /// - If the `Streamer` is already disconnected, then the connected status is forward and the publisher completes immediately.
    /// - If the `Streamer` is already is a connection process, the events from that publisher are forwarded here.
    ///
    /// - returns: Forwards all statuses till it reliably disconnects from the server (in which case the status is sent and then the publisher completes). If the connection is not possible or the session has expired, an error is thrown.
    public func disconnect() -> IG.Streamer.ContinuousPublisher<IG.Streamer.Session.Status> {
        Future<IG.Streamer.ContinuousPublisher<IG.Streamer.Session.Status>,IG.Streamer.Error> { [weak streamer = self.streamer] (promise) in
                guard let streamer = streamer else {
                    return promise(.failure(.sessionExpired()))
                }
            
                let initialStatus = streamer.channel.disconnect()
                
                if case .disconnected(isRetrying: false) = initialStatus {
                    let result = Just<IG.Streamer.Session.Status>(initialStatus)
                        .setFailureType(to: IG.Streamer.Error.self)
                        .eraseToAnyPublisher()
                    return promise(.success(result))
                }
            
                var cancellable: AnyCancellable? = nil
                
                let subject = PassthroughSubject<IG.Streamer.Session.Status,IG.Streamer.Error>()
                cancellable = streamer.channel.statusPublisher.sink { [weak weakSubject = subject] in
                    if let generator = weakSubject {
                        generator.send($0)
                        guard case .disconnected(isRetrying: false) = $0 else { return }
                        generator.send(completion: .finished)
                    }
                    
                    cancellable?.cancel()
                    cancellable = nil
                }
            
                return promise(.success(subject.eraseToAnyPublisher()))
            }.flatMap(maxPublishers: .max(1)) { $0 }
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
    public func unsubscribeAll() -> IG.Streamer.ContinuousPublisher<String> {
        return PassthroughPublisher<String,IG.Streamer.Error> { [weak streamer = self.streamer] (subject) in
            guard let streamer = streamer else {
                return subject.send(completion: .failure(.sessionExpired()))
            }
            
            var unsubs: Dictionary<IG.Streamer.Subscription, Subscribers.Sink<Streamer.Subscription.Event,Never>> = [:]
            var errors: [(item: String, error: IG.Streamer.Subscription.Error)] = .init()
            var iterationsCompleted = false
            
            let handle: (_ sub: IG.Streamer.Subscription?, _ error: IG.Streamer.Subscription.Error?)->Void = {
                if let sub = $0, let sink = unsubs.removeValue(forKey: sub) {
                    sink.cancel()
                    
                    switch $1 {
                    case .none:  subject.send(sub.item)
                    case let e?: errors.append((sub.item, e))
                    }
                }
                
                guard iterationsCompleted, unsubs.isEmpty else { return }
                guard !errors.isEmpty else { return subject.send(completion: .finished) }
                
                let suggestion = "No problems should stam from this; however, if it happens frequently, please contact the repository maintainer"
                var error = IG.Streamer.Error(.invalidResponse, "Errors occurred while unsubscribing", suggestion: suggestion)
                for (item, underlying) in errors {
                    error.context.append(("Unsubscription error (item: \(item)", underlying))
                }
                subject.send(completion: .failure(error))
            }
            
            unsubs = .init(uniqueKeysWithValues: streamer.channel.unsubscribeAll().map { (subscription) in
                weak var sub = subscription
                return (subscription, .init(receiveCompletion: { (_) in
                    handle(sub, nil)
                }, receiveValue: {
                    switch $0 { // 4. All subscription events except `.unsubscribed` and `.error` are ignored
                    case .unsubscribed: handle(sub, nil)
                    case .error(let e): handle(sub, e)
                    case .updateReceived, .updateLost, .subscribed: return
                    }
                }))
            })
            
            iterationsCompleted = true
            #warning("Streamer: Clean listening to the subscriptions if this publisher has ended before the unsubs ended.")
            for (sub, sink) in unsubs {
                sub.statusPublisher.subscribe(sink)
            }
            
            handle(nil, nil)
        }.eraseToAnyPublisher()
    }
}

//var disposables: [IG.Streamer.Subscription:AnyCancellable] = .init()
//var suberrors: [(item: String, error: IG.Streamer.Subscription.Error)] = .init()
//// 5. This closure is only call when a subscription has ended (whether with `.unsubscribed` or `.error`
//let handle: (_ subscription: IG.Streamer.Subscription, _ event: IG.Streamer.Subscription.Error?) -> Void = {
//    guard let cancellable = disposables.removeValue(forKey: $0) else { return }
//
//    switch $1 {
//    case .none:  subject.send($0.item)
//    case let e?: suberrors.append(($0.item, e))
//    }
//
//    cancellable.cancel()
//    guard !disposables.isEmpty else { return }
//    guard !suberrors.isEmpty else { return subject.send(completion: .finished) }
//
//    let suggestion = "No problems should stam from this; however, if it happens frequently, please contact the repository maintainer"
//    var error = IG.Streamer.Error(.invalidResponse, "Errors occurred while unsubscribing", suggestion: suggestion)
//    for (item, underlying) in suberrors {
//        error.context.append(("Unsubscription error (item: \(item)", underlying))
//    }
//    subject.send(completion: .failure(error))
//}

// MARK: - Entities

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
