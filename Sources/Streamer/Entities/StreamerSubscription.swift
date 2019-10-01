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
        
        /// Subject managing the current channel status and its publisher.
        @nonobjc private let mutableStatus: CurrentValueSubject<IG.Streamer.Subscription.Event,Never>
        /// Returns a publisher to subscribe to status events (the current value is sent first).
        @nonobjc internal let statusPublisher: AnyPublisher<IG.Streamer.Subscription.Event,Never>
        /// Returns the current subscription status.
        @nonobjc internal var status: IG.Streamer.Subscription.Event { self.mutableStatus.value }
        
        /// Initializes a subscription which is not yet connected to the server.
        ///
        /// Each subscription will have its own serial `DispatchQueue`.
        /// - parameter mode: The Lightstreamer mode to use on subscription.
        /// - parameter item: The item being subscrbed to (e.g. "MARKET" or "ACCOUNT").
        /// - parameter fields: The properties/fields of the item being targeted for subscription.
        /// - parameter snapshot: Boolean indicating whether we need snapshot data.
        /// - parameter queue: The parent/channel dispatch queue.
        @nonobjc init(mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool, targetQueue: DispatchQueue) {
            let childLabel = targetQueue.label + "." + mode.rawValue.lowercased()
            self.queue = DispatchQueue(label: childLabel, qos: targetQueue.qos, autoreleaseFrequency: .workItem, target: targetQueue)
            
            self.mutableStatus = .init(.unsubscribed)
            self.statusPublisher = self.mutableStatus.removeDuplicates {
                switch ($0, $1) {
                case (.subscribed, .subscribed), (.error, .error), (.unsubscribed, .unsubscribed): return true
                default: return false
                }
            }.eraseToAnyPublisher()
            
            self.item = item
            self.fields = fields
            self.lowlevel = LSSubscription(mode: mode.rawValue, item: item, fields: fields)
            #warning("Streamer: Check whether snapshoting works")
            self.lowlevel.requestedSnapshot = (snapshot) ? "yes" : "no"
            super.init()
            
            self.lowlevel.add(delegate: self)
        }
        
        deinit {
            self.lowlevel.remove(delegate: self)
        }
    }
}

extension IG.Streamer.Subscription: LSSubscriptionDelegate {
    @objc func didSubscribe(to subscription: LSSubscription) {
        self.queue.async { [property = self.mutableStatus] in
            property.value = .subscribed
        }
    }
    
    @objc func didUnsubscribe(from subscription: LSSubscription) {
        self.queue.async { [property = self.mutableStatus] in
            property.value = .unsubscribed
        }
    }
    
    @objc func didFail(_ subscription: LSSubscription, errorCode code: Int, message: String?) {
        self.queue.async { [property = self.mutableStatus] in
            property.value = .error(.init(code: code, message: message))
        }
    }
    
    @objc func didUpdate(_ subscription: LSSubscription, item itemUpdate: LSItemUpdate) {
        self.queue.async { [property = self.mutableStatus, fields = self.fields] in
            var result: [String:IG.Streamer.Subscription.Update] = .init(minimumCapacity: fields.count)
            for field in fields {
                let value = itemUpdate.value(withFieldName: field)
                result[field] = .init(value, isUpdated: itemUpdate.isValueChanged(withFieldName: field))
            }
            property.value = .updateReceived(result)
        }
    }
    
    @objc func didLoseUpdates(_ subscription: LSSubscription, count lostUpdates: UInt, itemName: String?, itemPosition itemPos: UInt) {
        self.queue.async { [property = self.mutableStatus] in
            property.value = .updateLost(count: lostUpdates, item: itemName)
        }
    }
//    @objc func didAddDelegate(to subscription: LSSubscription) {}
//    @objc func didRemoveDelegate(from subscription: LSSubscription) {}
//    @objc func subscription(_ subscription: LSSubscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {}
//    @objc func subscription(_ subscription: LSSubscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {}
}
