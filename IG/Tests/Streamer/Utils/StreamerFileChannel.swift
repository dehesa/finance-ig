@testable import IG
import ReactiveSwift
import XCTest

#warning("Streamer File Channel must be completely rework")

/// Mocked Lightstreamer session that will pick up responses from the bundle's file system.
final class StreamerFileChannel: StreamerMockableChannel {
    /// The central queue handling all events within the Streamer flow.
    private let queue: DispatchQueue
    
    let status: Property<Streamer.Session.Status>
    /// Returns the current streamer status.
    private let mutableStatus: MutableProperty<Streamer.Session.Status>
    
    init(rootURL: URL, credentials: Streamer.Credentials, queue: DispatchQueue) {
        self.queue = queue
        self.mutableStatus = .init(.disconnected(isRetrying: false))
        self.status = self.mutableStatus.skipRepeats()
    }
    
    func connect() {
        let status = self.mutableStatus
        guard case .disconnected(isRetrying: false) = status.value else { return }
        
        var counter: DispatchTime = .now() + .milliseconds(10)
        self.queue.asyncAfter(deadline: counter) {
            status.value = .connecting
        }
        
        counter = counter + .milliseconds(50)
        self.queue.asyncAfter(deadline: counter) {
            status.value = .connected(.sensing)
        }
        
        counter = counter + .milliseconds(50)
        self.queue.asyncAfter(deadline: counter) {
            status.value = .connected(.http(isPolling: false))
        }
    }
    
    func disconnect() {
        if case .disconnected(isRetrying: false) = self.mutableStatus.value { return }
        
        self.queue.asyncAfter(deadline: .now() + .milliseconds(50)) { [status = self.mutableStatus] in
            status.value = .disconnected(isRetrying: false)
        }
    }
    
    
    func subscribe(mode: Streamer.Mode, item: String, fields: [String], snapshot: Bool) -> SignalProducer<[String:Streamer.Subscription.Update], Streamer.Error> {
        return .empty
    }
    
    func unsubscribeAll() -> [Streamer.Subscription] {
        return []
    }
}

//    func makeSubscriptionSession<F:StreamerField>(mode: Streamer.Mode, items: Set<String>, fields: Set<F>) -> StreamerSubscriptionSession {
//        return StreamerFileSession.SubscriptionSession(mode: mode.rawValue, items: items, fields: Set(fields.map { $0.rawValue }))
//    }
//
//    var subscriptions: [Any] {
//        return self.subscriptionObjects as [Any]
//    }
//
//    func subscribe(to subscription: StreamerSubscriptionSession) {
//        guard case .none = self.subscriptionObjects.find({ $0 === subscription }) else { return }
//        self.subscriptionObjects.append(subscription)
//        // If the subscription is already active, the delegate has been added and there is no further work to do.
//        guard !subscription.isActive else { return }
//        // If the subscription instance is not of file type, there has been a major problem somewhere else.
//        guard let subSession = subscription as? StreamerFileSession.SubscriptionSession else {
//            fatalError("The subscription session is not a \"file subscription session\"")
//        }
//        // Send a value every second.
//        guard subSession.start(every: [1], rootURL: self.rootURL) else {
//            return self.unsubscribe(from: subscription)
//        }
//    }
//
//    func unsubscribe(from subscription: StreamerSubscriptionSession) {
//        guard let location = self.subscriptionObjects.locate({ $0 === subscription }) else { return }
//        self.subscriptionObjects.remove(at: location.index)
//
//        guard let subSession = subscription as? StreamerFileSession.SubscriptionSession else {
//            fatalError("The subscription session is not a \"file subscription session\"")
//        }
//        subSession.stop()
//    }
