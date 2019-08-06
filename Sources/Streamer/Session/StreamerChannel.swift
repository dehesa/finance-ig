import Lightstreamer_macOS_Client
import ReactiveSwift
import Foundation

internal protocol StreamerMockableChannel: class {
    /// Initializes the session setting up all parameters to be ready to connect.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    init(rootURL: URL, credentials: Streamer.Credentials)
    /// Returns the current streamer status.
    var status: Property<Streamer.Session.Status> { get }
    /// Requests to open the session against the Lightstreamer server.
    /// - note: This method doesn't check whether the channel is currently connected or not.
    func connect()
    /// Subscribe to the following item and field (in the given mode) requesting (or not) a snapshot.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter item: The item identfier (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    /// - returns: A producer providing updates as values. The producer will never complete, it will only be stoped by not holding a reference to the signal or by interrupting it with a disposable.
    func subscribe(mode: Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> SignalProducer<[String:Streamer.Subscription.Update],Streamer.Error>
    /// Unsubscribe to all ongoing subscriptions.
    /// - returns: All currently ongoing subscriptions.
    func unsubscribeAll() -> [Streamer.Subscription]
    /// Requests to close the Session opened against the configured Lightstreamer Server (if any).
    /// - note: Active sbuscription instances, associated with this LightstreamerClient instance, are preserved to be re-subscribed to on future Sessions.
    func disconnect()
}

extension Streamer {
    /// Contains all functionality related to the Streamer session.
    internal final class Channel: NSObject {
        /// Streamer credentials used to access the trading platform.
        @nonobjc private let credentials: Streamer.Credentials
        /// The central queue handling all events within the Streamer flow.
        @nonobjc private let queue: DispatchQueue
        /// The low-level lightstreamer client actually performing the network calls.
        /// - seealso: https://www.lightstreamer.com/repo/cocoapods/ls-ios-client/api-ref/2.1.2/classes.html
        @nonobjc private let client: LSLightstreamerClient
        /// All ongoing/active subscriptions.
        @nonobjc private var subscriptions: Set<Streamer.Subscription> = .init()
        
        @nonobjc internal let status: Property<Streamer.Session.Status>
        /// Returns the current streamer status.
        @nonobjc private let mutableStatus: MutableProperty<Streamer.Session.Status>
        
        @nonobjc init(rootURL: URL, credentials: Streamer.Credentials) {
            self.credentials = credentials
            
            let label = Bundle(for: Streamer.self).bundleIdentifier! + ".streamer"
            self.queue = DispatchQueue(label: label, qos: .realTimeMessaging, attributes: .concurrent, autoreleaseFrequency: .never)
            
            self.client = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil)
            self.client.connectionDetails.user = credentials.identifier
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

extension Streamer.Channel: StreamerMockableChannel {
    @nonobjc func connect() {
        self.client.connect()
    }
    
    @nonobjc func disconnect() {
        self.client.disconnect()
    }
    
    @nonobjc func subscribe(mode: Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> SignalProducer<[String:Streamer.Subscription.Update],Streamer.Error> {
        return .init { [weak self] (generator, lifetime) in
            guard let self = self else { return generator.send(error: .sessionExpired) }
            
            let subscription = Streamer.Subscription(mode: mode, item: item, fields: fields, snapshot: snapshot, target: self.queue)
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
                        var error = ErrorPrint(domain: "Streamer Channel", title: "\(item) with fields: \(fields.joined(separator: ","))")
                        error.append(details: "\(count) updates were lost before the next one arrived.")
                        print(error.debugDescription)
                        #endif
                        return
                    case .error(let error):
                        generator.send(error: .subscriptionFailed(item: item, fields: fields, error: error))
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
    
    @nonobjc func unsubscribeAll() -> [Streamer.Subscription] {
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

extension Streamer.Channel: LSClientDelegate {
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        guard let result = Streamer.Session.Status(rawValue: status) else {
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
