import Lightstreamer_macOS_Client
import ReactiveSwift
import Foundation

extension Streamer {
    /// Holds information about an ongoing subscription.
    internal final class Subscription: NSObject {
        /// The item being subscribed to.
        @nonobjc let item: String
        /// The fields being subscribed to.
        @nonobjc let fields: [String]
        /// The underlying Lightstreamer instance.
        @nonobjc let lowlevel: LSSubscription
        /// The dispatch queue processing the events and data.
        @nonobjc private let queue: DispatchQueue
        /// It forwards the lowlevel lightstreamer subscription events.
        @nonobjc private let events: MutableProperty<Streamer.Subscription.Event>
        /// Interface for the subscription state.
        @nonobjc internal let status: Property<Streamer.Subscription.Event>
        
        /// Initializes a subscription which is not yet connected to the server.
        /// - parameter mode: The Lightstreamer mode to use on subscription.
        /// - parameter item: The item being subscrbed to (e.g. "MARKET" or "ACCOUNT").
        /// - parameter fields: The properties/fields of the item being targeted for subscription.
        /// - parameter snapshot: Boolean indicating whether we need snapshot data.
        /// - parameter queue: The parent/channel dispatch queue.
        @nonobjc init(mode: Streamer.Mode, item: String, fields: [String], snapshot: Bool, target: DispatchQueue) {
            self.events = .init(.unsubscribed)
            self.status = self.events.skipRepeats { (lhs, rhs) -> Bool in
                switch (lhs, rhs) {
                case (.subscribed, .subscribed),
                     (.error, .error),
                     (.unsubscribed, .unsubscribed): return true
                default: return false
                }
            }
            
            let childLabel = target.label + "." + mode.rawValue.lowercased()
            self.queue = DispatchQueue(label: childLabel, qos: .realTimeMessaging, autoreleaseFrequency: .inherit, target: target)
            
            self.item = item
            self.fields = fields
            self.lowlevel = LSSubscription(mode: mode.rawValue, item: item, fields: fields)
            self.lowlevel.requestedSnapshot = (snapshot) ? "yes" : "no"
            super.init()
            
            self.lowlevel.add(delegate: self)
        }
        
        deinit {
            self.lowlevel.remove(delegate: self)
        }
    }
}

extension Streamer.Subscription: LSSubscriptionDelegate {
    @objc func didSubscribe(to subscription: LSSubscription) {
        self.queue.async { [property = self.events] in
            property.value = .subscribed
        }
    }
    
    @objc func didUnsubscribe(from subscription: LSSubscription) {
        self.queue.async { [property = self.events] in
            property.value = .unsubscribed
        }
    }
    
    @objc func didFail(_ subscription: LSSubscription, errorCode code: Int, message: String?) {
        self.queue.async { [property = self.events] in
            property.value = .error(.init(code: code, message: message))
        }
    }
    
    @objc func didUpdate(_ subscription: LSSubscription, item itemUpdate: LSItemUpdate) {
        self.queue.async { [property = self.events, fields = self.fields] in
            var result: [String:Streamer.Subscription.Update] = .init(minimumCapacity: fields.count)
            for field in fields {
                let value = itemUpdate.value(withFieldName: field)
                result[field] = .init(value, isUpdated: itemUpdate.isValueChanged(withFieldName: field))
            }
            property.value = .updateReceived(result)
        }
    }
    
    @objc func didLoseUpdates(_ subscription: LSSubscription, count lostUpdates: UInt, itemName: String?, itemPosition itemPos: UInt) {
        self.queue.async { [property = self.events] in
            property.value = .updateLost(count: lostUpdates, item: itemName)
        }
    }
//    @objc func didAddDelegate(to subscription: LSSubscription) {}
//    @objc func didRemoveDelegate(from subscription: LSSubscription) {}
//    @objc func subscription(_ subscription: LSSubscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {}
//    @objc func subscription(_ subscription: LSSubscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {}
}
