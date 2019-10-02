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
        ///
        /// This publisher remove duplicates (i.e. there aren't any repeating statuses).
        @nonobjc private let mutableStatus: CurrentValueSubject<IG.Streamer.Session.Status,Never>
        @nonobjc let statusPublisher: AnyPublisher<IG.Streamer.Session.Status,Never>
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
        /// The type of publisher passed by the future
        typealias SubscriptionPublisher = PassthroughSubject<[String:IG.Streamer.Subscription.Update],IG.Streamer.Error>
        
        var cancellable: AnyCancellable? = nil
        var subscription: IG.Streamer.Subscription? = nil
        
        let cleanup: ()->Void = { [weak self] in
            defer { cancellable = nil; subscription = nil}
            cancellable?.cancel()
            guard let representation = subscription, let self = self,
                  let lowlevel = self.subscriptions.remove(representation)?.lowlevel,
                  lowlevel.isActive else { return }
            dispatchPrecondition(condition: .notOnQueue(self.queue))
            self.queue.sync { self.client.unsubscribe(lowlevel) }
        }
        
        return Future<SubscriptionPublisher,IG.Streamer.Error> { [weak self] (promise) in
                guard let self = self else {
                    return promise(.failure(.sessionExpired()))
                }
            
                let representation = IG.Streamer.Subscription(mode: mode, item: item, fields: fields, snapshot: snapshot, targetQueue: self.queue)
                subscription = representation
                self.subscriptions.insert(representation)
                defer {
                    dispatchPrecondition(condition: .notOnQueue(self.queue))
                    self.queue.sync { self.client.subscribe(representation.lowlevel) }
                }
                
                let subject: SubscriptionPublisher = .init()
            
                var receivedFirstStatus = false
                cancellable = representation.statusPublisher.drop {
                    guard !receivedFirstStatus else { return false }
                    receivedFirstStatus = true
                    return $0 == .unsubscribed
                }.sink {
                    switch $0 {
                    case .updateReceived(let update):
                        subject.send(update)
                    case .subscribed:
                        #if DEBUG
                        print("\(IG.Streamer.printableDomain): Subscription to \(item) established")
                        #endif
                        break
                    case .updateLost(let count, let receivedItem):
                        #if DEBUG
                        print("\(IG.Streamer.printableDomain): Subscription to \(receivedItem ?? item) lost \(count) updates. Fields: [\(fields.joined(separator: ","))]")
                        #endif
                        break
                    case .error(let e):
                        let message = "The subscription couldn't be established"
                        let error: IG.Streamer.Error = .subscriptionFailed(.init(message), item: item, fields: fields, underlying: e, suggestion: .reviewError)
                        subject.send(completion: .failure(error))
                    case .unsubscribed:
                        #if DEBUG
                        print("\(IG.Streamer.printableDomain): Unsubscribed to \(item)")
                        #endif
                        subject.send(completion: .finished)
                    }
                }
                
                promise(.success(subject))
            }.flatMap(maxPublishers: .max(1)) {$0 }
            .handleEvents(receiveCompletion: { (_) in cleanup() }, receiveCancel: cleanup)
            .eraseToAnyPublisher()
    }
    
    @nonobjc func unsubscribeAll() -> [IG.Streamer.Subscription] {
        dispatchPrecondition(condition: .notOnQueue(self.queue))
        
        return queue.sync {
            let subscriptions = self.subscriptions
            self.subscriptions.removeAll()
            
            return subscriptions.filter {
                guard $0.lowlevel.isActive else { return false }
                self.client.unsubscribe($0.lowlevel)
                return true
            }
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
