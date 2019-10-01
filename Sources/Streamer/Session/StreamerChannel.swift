#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#else
#error("OS currently not supported")
#endif
import Combine
import Foundation

extension IG.Streamer {
    /// Contains all functionality related to the Streamer session.
    internal final class Channel: NSObject {
        /// Streamer credentials used to access the trading platform.
        @nonobjc private let credentials: IG.Streamer.Credentials
        /// The central queue handling all events within the Streamer flow.
        @nonobjc private unowned let queue: DispatchQueue
        /// The low-level lightstreamer client actually performing the network calls.
        /// - seealso: https://www.lightstreamer.com/repo/cocoapods/ls-ios-client/api-ref/2.1.2/classes.html
        @nonobjc private let client: LSLightstreamerClient
        /// All ongoing/active subscriptions.
        @nonobjc private var subscriptions: Set<IG.Streamer.Subscription> = .init()
        
        /// Subject managing the current channel status and its publisher.
        @nonobjc private let mutableStatus: CurrentValueSubject<IG.Streamer.Session.Status,Never>
        /// Returns a publisher to subscribe to status events (the current value is sent first).
        @nonobjc let statusPublisher: AnyPublisher<IG.Streamer.Session.Status,Never>
        /// Returns the current streamer status.
        @nonobjc var status: IG.Streamer.Session.Status { self.mutableStatus.value }
        
        @nonobjc init(rootURL: URL, credentials: IG.Streamer.Credentials, queue: DispatchQueue) {
            self.credentials = credentials
            self.queue = queue
            self.client = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil)
            self.client.connectionDetails.user = credentials.identifier.rawValue
            self.client.connectionDetails.setPassword(credentials.password)
            self.mutableStatus = .init(.disconnected(isRetrying: false))
            self.statusPublisher = self.mutableStatus.removeDuplicates().eraseToAnyPublisher()
            super.init()
            
            // The client stores the delegate weakly, therefore there is no reference cycle.
            self.client.addDelegate(self)
        }
        
        deinit {
            self.client.removeDelegate(self)
        }
        
        /// The Lightstreamer library version.
        static var lightstreamerVersion: String {
            return LSLightstreamerClient.lib_VERSION
        }
    }
}

extension IG.Streamer.Channel: StreamerMockableChannel {
    @nonobjc func connect() throws -> IG.Streamer.Session.Status {
        dispatchPrecondition(condition: .notOnQueue(self.queue))
        
        return try queue.sync {
            let currentValue = self.mutableStatus.value
            switch currentValue {
            case .stalled:
                let message = "The Streamer is connected, but silent"
                let suggestion = "Disconnect and connect again"
                throw IG.Streamer.Error.invalidRequest(.init(message), suggestion: .init(suggestion))
            case .disconnected(isRetrying: false):
                self.client.connect()
                fallthrough
            case .connected, .connecting, .disconnected(isRetrying: true):
                return currentValue
            }
        }
    }
    
    @nonobjc func disconnect() -> IG.Streamer.Session.Status {
        dispatchPrecondition(condition: .notOnQueue(self.queue))
        
        return queue.sync {
            let currentStatus = self.mutableStatus.value
            if case .disconnected(isRetrying: false) = currentStatus { return currentStatus }
            self.client.disconnect()
            return currentStatus
        }
    }
    
    @nonobjc func subscribe(mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> IG.Streamer.ContinuousPublisher<[String:IG.Streamer.Subscription.Update]> {
        typealias SubscribeSubject = PassthroughSubject<[String:IG.Streamer.Subscription.Update],IG.Streamer.Error>
        #warning("Streamer: When I cancel, everything is cancelled")
        var sharedSubject: SubscribeSubject? = nil
        return Future<SubscribeSubject,IG.Streamer.Error> { [weak self] (promise) in
                guard let self = self else {
                    return promise(.failure(.sessionExpired()))
                }
            
                if let subject = sharedSubject {
                    return promise(.success(subject))
                }
            
                let subscription = IG.Streamer.Subscription(mode: mode, item: item, fields: fields, snapshot: snapshot, targetQueue: self.queue)
                self.subscriptions.insert(subscription)
                
                promise(.success(sharedSubject!))
            }.switchToLatest().eraseToAnyPublisher()
        
//            let subscription = IG.Streamer.Subscription(mode: mode, item: item, fields: fields, snapshot: snapshot, targetQueue: self.queue)
//            self.subscriptions.insert(subscription)
//            /// When triggered, it stops listening to the subscription's statuses.
//            var detacher: Disposable? = nil
//            /// Cleans up everything related with the subscription (i.e. listeners, intermediate storage, and unsubscribes).
//            let cleanup: ()->Void = { [weak self, weak subscription] in
//                detacher?.dispose()
//                guard let self = self, let subscription = subscription else { return }
//                self.subscriptions.remove(subscription)
//                self.client.unsubscribe(subscription.lowlevel)
//            }
//
//            detacher = lifetime += subscription.status.signal.observe {
//                switch $0 {
//                case .value(let event):
//                    switch event {
//                    case .updateReceived(let update):
//                        return generator.send(value: update)
//                    case .updateLost(let count, _):
//                        #if DEBUG
//                        debugPrint("Streamer subscription lost \(count) updates from \(item) [\(fields.joined(separator: ","))]")
//                        #endif
//                        return
//                    case .error(let error):
//                        let message = "The subscription couldn't be established"
//                        let error: IG.Streamer.Error = .subscriptionFailed(message, item: item, fields: fields, underlying: error, suggestion: IG.Streamer.Error.Suggestion.reviewError)
//                        generator.send(error: error)
//                    case .subscribed, .unsubscribed: // Subscription and unsubscription may happen for temporary loss of connection.
//                        return
//                    }
//                case .completed: // The signal shall only complete when the subscription instance is deinitialized (i.e. when `unsubscribeAll()` is used)
//                    generator.sendInterrupted()
//                case .interrupted: // The signal shall only be interrupted by stopping the result producer's lifetime
//                    break
//                case .failed: // The signal shall never fail
//                    fatalError("A subscription status property cannot fail")
//                }
//
//                return cleanup()
//            }
//
//            self.client.subscribe(subscription.lowlevel)
    }
    
    @nonobjc func unsubscribeAll() -> [IG.Streamer.Subscription] {
        let subscriptions = self.subscriptions
        self.subscriptions.removeAll()
        
        return subscriptions.filter {
            guard $0.lowlevel.isActive else { return false }
            self.client.unsubscribe($0.lowlevel)
            return true
        }
    }
}

// MARK: - Lightstreamer Delegate

extension IG.Streamer.Channel: LSClientDelegate {
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        guard let result = IG.Streamer.Session.Status(rawValue: status) else {
            fatalError("Lightstreamer client status \"\(status)\" was not recognized")
        }
        
        self.queue.async { [subject = self.mutableStatus] in
            subject.value = result
        }
    }
    //@objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) { <#code#> }
    //@objc func didAddDelegate(to: LSLightstreamerClient) { <#code#> }
    //@objc func didRemoveDelegate(to: LSLightstreamerClient) { <#code#> }
}
