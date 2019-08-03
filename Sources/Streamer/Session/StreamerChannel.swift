import Lightstreamer_macOS_Client
import ReactiveSwift
import Foundation

internal protocol StreamerMockableChannel {
    /// Initializes the session setting up all parameters to be ready to connect.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    init(rootURL: URL, credentials: Streamer.Credentials)
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
        /// The central queue handling all events within the Streamer flow.
        @nonobjc private let queue: DispatchQueue
        /// The low-level lightstreamer client actually performing the network calls.
        /// - seealso: https://www.lightstreamer.com/repo/cocoapods/ls-ios-client/api-ref/2.1.2/classes.html
        @nonobjc private let client: LSLightstreamerClient
        /// Returns the current streamer status.
        @nonobjc private let mutableStatus: MutableProperty<Streamer.Session.Status>
        /// All ongoing subscriptions.
        @nonobjc private var subscriptions: Set<Streamer.Subscription> = .init()
        
        @nonobjc init(rootURL: URL, credentials: Streamer.Credentials) {
            self.credentials = credentials
            
            let label = Bundle(for: Streamer.self).bundleIdentifier! + ".streamer"
            self.queue = DispatchQueue(label: label, qos: .realTimeMessaging, attributes: .concurrent, autoreleaseFrequency: .never)
            
            self.client = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil)
            self.client.connectionDetails.user = credentials.identifier
            self.client.connectionDetails.setPassword(credentials.password)
            self.mutableStatus = MutableProperty<Streamer.Session.Status>(.disconnected(isRetrying: false))
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
        return .init { [weak self] (generator, lifetime) in
            guard let self = self else { return generator.send(error: .sessionExpired) }
            
            let (subscription, signal) = Streamer.Subscription.make(mode: mode, item: item, fields: fields, snapshot: snapshot, queue: self.queue)
            // When the user finishes the producer, the low-level instance is unsubscribed.
            lifetime.observeEnded { [weak self, weak subscription] in
                guard let self = self,
                      let sub = subscription,
                      sub.lowlevel.isActive else { return }
                self.client.unsubscribe(sub.lowlevel)
            }
            // When the user finishes the producer, the bond to the signal is severed.
            lifetime += signal.observe {
                guard case .value(let subscriptionEvent) = $0 else {
                    return generator.sendCompleted()
                }
                
                switch subscriptionEvent {
                case .updateReceived(let update):
                    #warning("Maybe set the dictionary as [String:Any] or an optional as value. There are crashes; e.g. with ODDS in sprint markets.")
                    if let values = update.fields as? [String:String] {
                        generator.send(value: values)
                    } else {
                        generator.send(error: .invalidResponse(item: item, fields: update.fields, message: "The update values couldn't be turned into a [String:String] dictionary."))
                    }
                case .updateLost(let count, _):
                    var error = ErrorPrint(domain: "Streamer Channel", title: "\(item) with fields: \(fields.joined(separator: ","))")
                    error.append(details: "\(count) updates were lost before the next one arrived.")
                    print(error.debugDescription)
                case .subscriptionSucceeded: return
                    // return print("\nSubscribed!!\n")
                case .unsubscribed: return
                    // return print("\nSuccessfully unsubscribed.\n")
                case .subscriptionFailed(let error):
                    generator.send(error: .subscriptionFailed(item: item, fields: fields, error: error))
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
