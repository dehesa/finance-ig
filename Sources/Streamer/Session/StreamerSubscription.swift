import Lightstreamer_macOS_Client
import ReactiveSwift
import Foundation

extension Streamer {
    /// Holds information about an ongoing subscription.
    internal final class Subscription: NSObject {
        /// The signal sending events through the lifetime of the subscription instance.
        typealias EventSignal = Signal<Streamer.Subscription.Event,Never>
        
        /// The underlying Lightstreamer instance.
        let lowlevel: LSSubscription
        /// The dispatch queue processing the events and data.
        private let queue: DispatchQueue
        /// The signal input sending/generatign all events.
        internal let generator: EventSignal.Observer
        
        /// Designated initializer passing all needed instances and setting the delegate on the underlying Lightstreamer instance.
        private init(lowlevel: LSSubscription, queue: DispatchQueue, generator: EventSignal.Observer) {
            self.lowlevel = lowlevel
            self.queue = queue
            self.generator = generator
            super.init()
            
            self.lowlevel.addDelegate(self)
        }
        
        /// Produces the subscription instance and a signal forwarding all subscription events.
        /// - parameter mode: The Lightstreamer mode to use on subscription.
        /// - parameter item: The item being subscrbed to (e.g. "MARKET" or "ACCOUNT").
        /// - parameter fields: The properties/fields of the item being targeted for subscription.
        /// - parameter snapshot: Boolean indicating whether we need snapshot data.
        /// - parameter queue: The parent/channel dispatch queue.
        /// - returns: The signal will complete when the subscription instance is deinitialize.
        static func make(mode: Streamer.Mode, item: String, fields: [String], snapshot: Bool, queue: DispatchQueue) -> (subscription: Streamer.Subscription, signal: EventSignal) {
            let childLabel = queue.label + "." + mode.rawValue.lowercased()
            let childQueue = DispatchQueue(label: childLabel, qos: .realTimeMessaging, attributes: [], autoreleaseFrequency: .inherit, target: queue)
            
            let lowlevel = LSSubscription(subscriptionMode: mode.rawValue, item: item, fields: fields)
            lowlevel.requestedSnapshot = (snapshot) ? "yes" : "no"
            
            let (signal, generator) = EventSignal.pipe()
            let subscription = Self.init(lowlevel: lowlevel, queue: childQueue, generator: generator)
            return (subscription, signal)
        }
        
        deinit {
            self.generator.sendCompleted()
        }
    }
}

extension Streamer.Subscription: LSSubscriptionDelegate {
    @objc func subscriptionDidSubscribe(_ subscription: LSSubscription) {
        self.queue.async { [generator = self.generator] in
            generator.send(value: .subscriptionSucceeded)
        }
    }
    
    @objc func subscriptionDidUnsubscribe(_ subscription: LSSubscription) {
        self.queue.async { [generator = self.generator] in
            generator.send(value: .unsubscribed)
        }
    }
    
    @objc func subscription(_ subscription: LSSubscription, didFailWithErrorCode code: Int, message: String?) {
        self.queue.async { [generator = self.generator] in
            generator.send(value: .subscriptionFailed(error: .init(code: code, message: message)))
        }
    }
    
    @objc func subscription(_ subscription: LSSubscription, didUpdateItem itemUpdate: LSItemUpdate) {
        self.queue.async { [generator = self.generator] in
            generator.send(value: .updateReceived(itemUpdate))
        }
    }
    
    @objc func subscription(_ subscription: LSSubscription, didLoseUpdates lostUpdates: UInt, forItemName itemName: String?, itemPos: UInt) {
        self.queue.async { [generator = self.generator] in
            generator.send(value: .updateLost(count: lostUpdates, item: itemName))
        }
    }
//    @objc func subscriptionDidAdd(_ subscription: LSSubscription) {}
//    @objc func subscriptionDidRemove(_ subscription: LSSubscription) {}
//    @objc func subscription(_ subscription: LSSubscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {}
//    @objc func subscription(_ subscription: LSSubscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {}
//    @objc func subscription(_ subscription: LSSubscription, didLoseUpdates lostUpdates: UInt, forCommandSecondLevelItemWithKey key: String) {}
//    @objc func subscription(_ subscription: LSSubscription, didFailWithErrorCode code: Int, message: String?, forCommandSecondLevelItemWithKey key: String)
}
