import ReactiveSwift
import Foundation

/// The Streamer instance is the bridge to the Streaming service provided by IG.
public final class Streamer {
    /// The lifetime observer for the receiving `Streamer` instance.
    internal let lifetime: Lifetime
    /// The lifetime token that will dispose of all the state of the receiving `Streamer` instance.
    private let token: Lifetime.Token
    /// URL root address.
    public let rootURL: URL
    /// The session (whether real or mocked) managing the streaming connections.
    internal let channel: StreamerMockableChannel
    
    /// It holds functionality related to the current streamer session.
    public var session: Streamer.Request.Session { return .init(streamer: self) }
    
    
    /// Creates a `Streamer` instance with the provided credentails and start it right away.
    ///
    /// If you set `autoconnect` to `false` you need to remember to call `connect` on the returned instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    /// - parameter autoconnect: Boolean indicating whether the `connect()` function is called right away, or whether it shall be called later on by the user.
    public convenience init(rootURL: URL, credentials: Streamer.Credentials, autoconnect: Bool = true) {
        let session = Streamer.Channel(rootURL: rootURL, credentials: credentials)
        self.init(rootURL: rootURL, session: session, autoconnect: autoconnect)
    }
    
    /// Initializer for a Streamer instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter session: Real or mocked session managing the streaming connections.
    /// - parameter autoconnect: Booleain indicating whether the `connect()` function is called right away, or whether it shall be called later on by the user.
    internal init(rootURL: URL, session: Streamer.Channel, autoconnect: Bool) {
        (self.lifetime, self.token) = Lifetime.make()
        self.rootURL = rootURL
        self.channel = session
        
        guard autoconnect else { return }
        self.channel.connect()
    }
    
    deinit {
//        self.session.unsubscribeAll()
        self.channel.disconnect()
        self.token.dispose()
    }
}

//extension Streamer {
//    /// Starts a subscription and sends the event to the listener.
//    /// - parameter subscription: The subscription info and event listener.
//    fileprivate func subscribe(to subscription: Streamer.Subscription) {
//        guard !subscription.session.isActive else { return }
//        self.session.subscribe(to: subscription.session)
//    }
//
//    /// Stops a subscription (stopping any event forwarding).
//    /// - parameter subscription: The subscription info and event listener.
//    fileprivate func unsubscribe(to subscription: Streamer.Subscription) {
//        guard subscription.session.isActive else { return }
//        self.session.unsubscribe(from: subscription.session)
//    }
//
//    /// Returns the information about where to subscription and how the `DispatchQueue` should be named.
//    /// - throws: A `Streamer.Error` in case of invalid request.
//    internal typealias SubscriptionPreparation = (_ streamer: Streamer) throws -> (label: String, subscriptionSession: StreamerSubscriptionSession)
//    /// Received all events from the subscription producer.
//    internal typealias SubscriptionEventHandler<R> = (_ input: Signal<R,Streamer.Error>.Observer, _ event: Streamer.Subscription.Event) -> Void
//
//    /// Creates a `SignalProducer` that will subscribe to the subscription session passed in the `information` closure.
//    ///
//    /// All further events after the signal is started will arrive to the `eventHandler`.
//    /// - parameter startHandler: The preparation closure indicating where to subscribe.
//    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically (and implicitly) or whether it should wait for the user to explicitly call `connect()`.
//    /// - parameter eventHandler: Closure receiving all events once the signal producer has been started.
//    /// - returns: The `SignalProducer` subscribing to the given information.
//    internal func subscriptionProducer<R>(_ startHandler: @escaping SubscriptionPreparation, autoconnect: Bool = true, eventHandler: @escaping SubscriptionEventHandler<R>) -> SignalProducer<R,Streamer.Error> {
//        return SignalProducer { [weak weakStreamer = self] (input, lifetime) in
//            // The signalProduce can be started at any time; a.k.a. it can easily outlive the streamer session.
//            // If the signalProducer is started when the streamer session is not there, automatically generate and error and finish without performing any work.
//            guard let streamer = weakStreamer else { return input.send(error: .sessionExpired) }
//
//            // The signal being created will listen for the streamer session deinitialization. If the session disappears while the signalProducer is generating events, an error is generated.
//            // Also, the session deinitialization observer will be detached, if the signal being created finishes.
//            lifetime += streamer.lifetime.observeEnded { [unowned input] in input.send(error: .sessionExpired) }
//
//            // Get the label for the subscription `DispatchQueue` and the actual Subscription instance.
//            let (label, subscriptionSession): (String, StreamerSubscriptionSession)
//            do {
//                (label , subscriptionSession) = try startHandler(streamer)
//            } catch let error {
//                return input.send(error: error as! Streamer.Error)
//            }
//
//            // The subscription will have its own GCD serial queue offloading all their events in the general streamer session queue.
//            let queue = DispatchQueue(label: label, qos: .realTimeMessaging, autoreleaseFrequency: .inherit, target: streamer.queue)
//
//            // A subscription session is needed. This session will handle all events received targeting the subscription events.
//            var subscription: Subscription! = Subscription(session: subscriptionSession, queue: queue)
//
//            // The signal being created must own the subscription instance so it won't go at the end of the signal creation.
//            lifetime.observeEnded {
//                weakStreamer?.unsubscribe(to: subscription)
//                subscription = nil  // The subscription bond is broken when the signal deinitializes.
//            }
//
//            // Subscription events will be listened to till the signal deinitializes.
//            lifetime += subscription.events.observeValues { (event) in
//                eventHandler(input, event)
//            }
//
//            streamer.subscribe(to: subscription)
//
//            if autoconnect { streamer.connect() }
//        }
//    }
//}
