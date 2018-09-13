import ReactiveSwift
import Result
import Foundation

/// The Streamer instance is the bridge to the Streaming service provided by IG.
public final class Streamer {
    /// The session (whether real or mocked) managing the streaming connections.
    internal let session: StreamerSession
    /// The session delegate delegate.
    private let delegate: StreamerSessionDelegate
    /// The central queue handling all events within the Streamer flow.
    internal let queue: DispatchQueue
    /// The lifetime observer for the receiving `Streamer` instance.
    internal let lifetime: Lifetime
    /// The lifetime token that will dispose of all the state of the receiving `Streamer` instance.
    private let token: Lifetime.Token
    
    /// URL root address.
    public let rootURL: URL
    /// Returns the current streamer status.
    public let status: Property<Status>
    
    /// Initializer for a Streamer instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter session: Real or mocked session managing the streaming connections.
    /// - parameter autoconnect: Booleain indicating whether the `connect()` function is called right away, or whether it shall be called later on by the user.
    internal init(rootURL: URL, session: StreamerSession, autoconnect: Bool) {
        let label = Bundle(for: Streamer.self).bundleIdentifier! + ".streamer"
        self.queue = DispatchQueue(label: label, qos: .realTimeMessaging, attributes: .concurrent, autoreleaseFrequency: .never)
        
        (self.lifetime, self.token) = Lifetime.make()
        self.session = session
        let delegate = StreamerSessionObserver(session: self.session, queue: self.queue)
        self.delegate = delegate
        self.rootURL = rootURL
        self.status = delegate.status.skipRepeats()
        
        self.session.add(delegate: delegate)
        if autoconnect { self.session.connect() }
    }
    
    deinit {
        self.session.unsubscribeAll()
        self.session.disconnect()
        self.session.remove(delegate: self.delegate)
        self.token.dispose()
    }
    
    /// Connects the session with the server.
    ///
    /// If the session is already connected or, is in one of the retrying processes, this message is ignored.
    public func connect() {
        guard case .disconnected(let isRetrying) = self.status.value,
              isRetrying == false else { return }
        self.session.connect()
    }
    
    /// Disconnects the session from the server.
    public func disconnect() {
        self.session.disconnect()
    }
    
    /// List of request data needed to make subscriptions.
    public enum Request {}
    /// List of responses received from subscriptions.
    public enum Response {}
}

extension Streamer {
    /// Starts a subscription and sends the event to the listener.
    /// - parameter subscription: The subscription info and event listener.
    fileprivate func subscribe(to subscription: Streamer.Subscription) {
        guard !subscription.session.isActive else { return }
        self.session.subscribe(to: subscription.session)
    }
    
    /// Stops a subscription (stopping any event forwarding).
    /// - parameter subscription: The subscription info and event listener.
    fileprivate func unsubscribe(to subscription: Streamer.Subscription) {
        guard subscription.session.isActive else { return }
        self.session.unsubscribe(from: subscription.session)
    }
    
    /// Returns the information about where to subscription and how the `DispatchQueue` should be named.
    /// - throws: A `Streamer.Error` in case of invalid request.
    internal typealias SubscriptionPreparation = (_ streamer: Streamer) throws -> (label: String, subscriptionSession: StreamerSubscriptionSession)
    /// Received all events from the subscription producer.
    internal typealias SubscriptionEventHandler<R> = (_ input: Signal<R,Streamer.Error>.Observer, _ event: Streamer.Subscription.Event) -> Void
    
    /// Creates a `SignalProducer` that will subscribe to the subscription session passed in the `information` closure.
    ///
    /// All further events after the signal is started will arrive to the `eventHandler`.
    /// - parameter startHandler: The preparation closure indicating where to subscribe.
    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically (and implicitly) or whether it should wait for the user to explicitly call `connect()`.
    /// - parameter eventHandler: Closure receiving all events once the signal producer has been started.
    /// - returns: The `SignalProducer` subscribing to the given information.
    internal func subscriptionProducer<R>(_ startHandler: @escaping SubscriptionPreparation, autoconnect: Bool = true, eventHandler: @escaping SubscriptionEventHandler<R>) -> SignalProducer<R,Streamer.Error> {
        return SignalProducer { [weak weakStreamer = self] (input, lifetime) in
            // The signalProduce can be started at any time; a.k.a. it can easily outlive the streamer session.
            // If the signalProducer is started when the streamer session is not there, automatically generate and error and finish without performing any work.
            guard let streamer = weakStreamer else { return input.send(error: .sessionExpired) }
            
            // The signal being created will listen for the streamer session deinitialization. If the session disappears while the signalProducer is generating events, an error is generated.
            // Also, the session deinitialization observer will be detached, if the signal being created finishes.
            lifetime += streamer.lifetime.observeEnded { [unowned input] in input.send(error: .sessionExpired) }
            
            // Get the label for the subscription `DispatchQueue` and the actual Subscription instance.
            let (label, subscriptionSession): (String, StreamerSubscriptionSession)
            do {
                (label , subscriptionSession) = try startHandler(streamer)
            } catch let error {
                return input.send(error: error as! Streamer.Error)
            }
            
            // The subscription will have its own GCD serial queue offloading all their events in the general streamer session queue.
            let queue = DispatchQueue(label: label, qos: .realTimeMessaging, autoreleaseFrequency: .inherit, target: streamer.queue)
            
            // A subscription session is needed. This session will handle all events received targeting the subscription events.
            var subscription: Subscription! = Subscription(session: subscriptionSession, queue: queue)
            
            // The signal being created must own the subscription instance so it won't go at the end of the signal creation.
            lifetime.observeEnded {
                weakStreamer?.unsubscribe(to: subscription)
                subscription = nil  // The subscription bond is broken when the signal deinitializes.
            }
            
            // Subscription events will be listened to till the signal deinitializes.
            lifetime += subscription.events.observeValues { (event) in
                eventHandler(input, event)
            }
            
            streamer.subscribe(to: subscription)
            
            if autoconnect { streamer.connect() }
        }
    }
}

/// Class wrapping all the session delegate calls.
/// - note: This must be an Obj-C class since it will be called by the Obj-C runtime system.
internal final class StreamerSessionObserver: NSObject, StreamerSessionDelegate {
    /// Returns the current streamer status.
    @nonobjc let status: MutableProperty<Streamer.Status>
    /// A signal generating as values all possible errors.
    @nonobjc let errors = Signal<Streamer.Error,NoError>.pipe()
    /// The session queue where all the events will be sent into.
    @nonobjc private unowned let queue: DispatchQueue
    
    /// Designated initializer setting up the parent/child bond.
    @nonobjc init(session: StreamerSession, queue: DispatchQueue) {
        self.queue = queue
        self.status = MutableProperty<Streamer.Status>(.disconnected(isRetrying: false))
        super.init()
        
        self.statusChanged(to: self.status.value, on: session)
    }
    
    @nonobjc func statusChanged(to status: Streamer.Status, on session: StreamerSession) {
        self.queue.async { [property = self.status] in
            property.value = status
        }
    }
}
