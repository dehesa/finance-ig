import Lightstreamer_macOS_Client
import ReactiveSwift
import Foundation

internal protocol StreamerMockableChannel {
    /// Initializes the session setting up all parameters to be ready to connect.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    /// - parameter lifetime: The streamer instance *lifetime* representation.
    init(rootURL: URL, credentials: Streamer.Credentials, lifetime: Lifetime)
    /// Returns the current streamer status.
    var status: Property<Streamer.Session.Status> { get }
    /// Requests to open the session against the Lightstreamer server.
    func connect()
    /// Subscribe to the following item and field (in the given mode) requesting (or not) a snapshot.
    /// - parameter mode: The streamer subscription mode.
    /// - parameter item: The item identfier (e.g. "MARKET", "ACCOUNT", etc).
    /// - parameter fields: The fields (or properties) from the given item to be received in the subscription.
    /// - parameter snapshot: Whether the current state of the given `fields` must be received as the first update.
    func subscribe(mode: Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> SignalProducer<[String:String],Streamer.Error>
    /// Unsubscribe to all subscriptions sending a complete event on all signals.
    func unsubscribeAll()
    /// Requests to close the Session opened against the configured Lightstreamer Server (if any).
    /// - note: Active sbuscription instances, associated with this LightstreamerClient instance, are preserved to be re-subscribed to on future Sessions.
    func disconnect()
}

extension Streamer {
    /// Contains all functionality related to the Streamer session.
    internal final class Channel: NSObject {
        /// Streamer credentials used to access the trading platform.
        @nonobjc private let credentials: Streamer.Credentials
        /// The hosting streamer instance *lifetime* representation.
        @nonobjc private unowned let lifetime: Lifetime
        /// The central queue handling all events within the Streamer flow.
        @nonobjc private let queue: DispatchQueue
        /// The low-level lightstreamer client actually performing the network calls.
        /// - seealso: https://www.lightstreamer.com/repo/cocoapods/ls-ios-client/api-ref/2.1.2/classes.html
        @nonobjc private let client: LSLightstreamerClient
        /// Returns the current streamer status.
        @nonobjc private let mutableStatus: MutableProperty<Streamer.Session.Status>
        /// All ongoing subscriptions.
        @nonobjc private var subscriptions: Set<Streamer.Subscription> = .init()
        
        @nonobjc init(rootURL: URL, credentials: Streamer.Credentials, lifetime: Lifetime) {
            self.credentials = credentials
            self.lifetime = lifetime
            
            let label = Bundle(for: Streamer.self).bundleIdentifier! + ".streamer"
            self.queue = DispatchQueue(label: label, qos: .realTimeMessaging, attributes: .concurrent, autoreleaseFrequency: .never)
            
            self.client = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil)
            self.client.connectionDetails.user = credentials.identifier
            self.client.connectionDetails.setPassword(credentials.password)
            self.mutableStatus = .init(.disconnected(isRetrying: false))
            super.init()
            
            // The client stores the delegate weakly, therefore there is no reference cycle.
            self.client.addDelegate(self)
        }
        
        deinit {
            self.unsubscribeAll()
            self.client.disconnect()
            self.client.removeDelegate(self)
        }
    }
}

extension Streamer.Channel: StreamerMockableChannel {
    @nonobjc var status: Property<Streamer.Session.Status> {
        self.mutableStatus.skipRepeats()
    }
    
    @nonobjc func connect() {
        self.client.connect()
    }
    
    @nonobjc func disconnect() {
        self.client.disconnect()
    }
    
    func subscribe(mode: Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> SignalProducer<[String:String],Streamer.Error> {
        return .init { [weak self] (resultGenerator, resultLifetime) in
            guard let self = self else { return resultGenerator.send(error: .sessionExpired) }
            
            let (subscription, underlyingSignal) = Streamer.Subscription.make(mode: mode, item: item, fields: fields, snapshot: snapshot, queue: self.queue, streamerLifetime: self.lifetime)
            
            // When the user is done with the producer, the low-level instance is unsubscribed.
            resultLifetime.observeEnded { [weak self, weak subscription] in
                guard let self = self, let subscription = subscription else { return }
                self.subscriptions.remove(subscription)
                
                guard subscription.lowlevel.isActive else { return }
                self.client.unsubscribe(subscription.lowlevel)
            }
            // When the user is done with the producer, the underlying subscription signal is not observe anymore.
            resultLifetime += underlyingSignal.observe {
                let event: Streamer.Subscription.Event
                switch $0 {
                case .value(let underlyingEvent):
                    event = underlyingEvent
                case .completed: // This triggers `resultLifetime.observeEnded`
                    return resultGenerator.sendCompleted()
                case .interrupted: // This triggers `resultLifetime.observeEnded`
                    return resultGenerator.sendInterrupted()
                case .failed(_):
                    fatalError("A signal subscription failed event should never happen.")
                }
                
                switch event {
                case .updateReceived(let update):
                    if let values = update.fields as? [String:String] {
                        resultGenerator.send(value: values)
                    } else {
                        resultGenerator.send(error: .invalidResponse(item: item, fields: update.fields, message: "The update values couldn't be turned into a [String:String] dictionary."))
                    }
                case .updateLost(let count, _):
                    var error = ErrorPrint(domain: "Streamer Channel", title: "\(item) with fields: \(fields.joined(separator: ","))")
                    error.append(details: "\(count) updates were lost before the next one arrived.")
                    print(error.debugDescription)
                case .subscriptionFailed(let error):
                    resultGenerator.send(error: .subscriptionFailed(item: item, fields: fields, error: error))
                case .subscriptionSucceeded, .unsubscribed: return
                }
            }
            
            self.subscriptions.insert(subscription)
            self.client.subscribe(subscription.lowlevel)
        }
    }
    
    func unsubscribeAll() {
        let subscriptions = self.subscriptions
        self.subscriptions.removeAll()
        
        for subscription in subscriptions {
            if subscription.lowlevel.isActive {
                self.client.unsubscribe(subscription.lowlevel)
            }
            subscription.generator.sendCompleted()
        }
    }
}

// MARK: - Lightstreamer Delegate

extension Streamer.Channel: LSClientDelegate {
    //@objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) { <#code#> }
    //@objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) { <#code#> }
    //@objc func clientDidAdd(_ client: LSLightstreamerClient) { <#code#> }
    //@objc func clientDidRemove(_ client: LSLightstreamerClient) { <#code#> }
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        guard let result = Streamer.Session.Status(rawValue: status) else {
            fatalError("Lightstreamer client status \"\(status)\" was not recognized.")
        }
        
        self.queue.async { [property = self.mutableStatus] in
            property.value = result
        }
    }
}
