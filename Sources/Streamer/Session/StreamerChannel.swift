import Lightstreamer_macOS_Client
import ReactiveSwift
import Foundation

extension IG.Streamer {
    /// Contains all functionality related to the Streamer session.
    internal final class Channel: NSObject {
        /// Streamer credentials used to access the trading platform.
        @nonobjc private let credentials: IG.Streamer.Credentials
        /// The central queue handling all events within the Streamer flow.
        @nonobjc private let queue: DispatchQueue
        /// The low-level lightstreamer client actually performing the network calls.
        /// - seealso: https://www.lightstreamer.com/repo/cocoapods/ls-ios-client/api-ref/2.1.2/classes.html
        @nonobjc private let client: LSLightstreamerClient
        /// All ongoing/active subscriptions.
        @nonobjc private var subscriptions: Set<IG.Streamer.Subscription> = .init()
        
        @nonobjc internal let status: Property<IG.Streamer.Session.Status>
        /// Returns the current streamer status.
        @nonobjc private let mutableStatus: MutableProperty<IG.Streamer.Session.Status>
        
        @nonobjc init(rootURL: URL, credentials: IG.Streamer.Credentials) {
            self.credentials = credentials
            
            let label = Bundle(for: IG.Streamer.self).bundleIdentifier! + ".streamer"
            self.queue = DispatchQueue(label: label, qos: .realTimeMessaging, attributes: .concurrent, autoreleaseFrequency: .never)
            
            self.client = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil)
            self.client.connectionDetails.user = credentials.identifier.rawValue
            self.client.connectionDetails.setPassword(credentials.password)
            self.mutableStatus = .init(.disconnected(isRetrying: false))
            self.status = self.mutableStatus.skipRepeats()
            super.init()
            
            // The client stores the delegate weakly, therefore there is no reference cycle.
            self.client.addDelegate(self)
        }
        
        deinit {
            self.client.removeDelegate(self)
        }
    }
}

extension IG.Streamer.Channel: StreamerMockableChannel {
    @nonobjc func connect() {
        self.client.connect()
    }
    
    @nonobjc func disconnect() {
        self.client.disconnect()
    }
    
    @nonobjc func subscribe(mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> SignalProducer<[String:IG.Streamer.Subscription.Update],IG.Streamer.Error> {
        return .init { [weak self] (generator, lifetime) in
            guard let self = self else { return generator.send(error: .sessionExpired()) }
            
            let subscription = IG.Streamer.Subscription(mode: mode, item: item, fields: fields, snapshot: snapshot, target: self.queue)
            self.subscriptions.insert(subscription)
            /// When triggered, it stops listening to the subscription's statuses.
            var detacher: Disposable? = nil
            /// Cleans up everything related with the subscription (i.e. listeners, intermediate storage, and unsubscribes).
            let cleanup: ()->Void = { [weak self, weak subscription] in
                detacher?.dispose()
                guard let self = self, let subscription = subscription else { return }
                self.subscriptions.remove(subscription)
                self.client.unsubscribe(subscription.lowlevel)
            }
            
            detacher = lifetime += subscription.status.signal.observe {
                switch $0 {
                case .value(let event):
                    switch event {
                    case .updateReceived(let update):
                        return generator.send(value: update)
                    case .updateLost(let count, _):
                        #if DEBUG
                        debugPrint("Streamer subscription lost \(count) updates from \(item) [\(fields.joined(separator: ","))].")
                        #endif
                        return
                    case .error(let error):
                        let message = "The subscription couldn't be established."
                        let error: IG.Streamer.Error = .subscriptionFailed(message, item: item, fields: fields, underlying: error, suggestion: IG.Streamer.Error.Suggestion.reviewError)
                        generator.send(error: error)
                    case .subscribed, .unsubscribed: // Subscription and unsubscription may happen for temporary loss of connection.
                        return
                    }
                case .completed: // The signal shall only complete when the subscription instance is deinitialized (i.e. when `unsubscribeAll()` is used)
                    generator.sendInterrupted()
                case .interrupted: // The signal shall only be interrupted by stopping the result producer's lifetime
                    break
                case .failed: // The signal shall never fail
                    fatalError("A subscription status property cannot fail")
                }
                
                return cleanup()
            }
            
            self.client.subscribe(subscription.lowlevel)
        }
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
            fatalError("Lightstreamer client status \"\(status)\" was not recognized.")
        }
        
        self.queue.async { [property = self.mutableStatus] in
            property.value = result
        }
    }
    //@objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) { <#code#> }
    //@objc func didAddDelegate(to: LSLightstreamerClient) { <#code#> }
    //@objc func didRemoveDelegate(to: LSLightstreamerClient) { <#code#> }
}
