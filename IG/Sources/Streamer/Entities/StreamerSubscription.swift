#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#else
#error("OS currently not supported")
#endif
import Combine

extension IG.Streamer {
    /// Holds information about an ongoing subscription.
    internal final class Subscription: NSObject {
        /// The item being subscribed to.
        @nonobjc final let item: String
        /// The fields being subscribed to.
        @nonobjc final let fields: [String]
        /// The underlying Lightstreamer instance.
        @nonobjc final let lowlevel: LSSubscription
        
        /// The current status for the receiving subscription.
        @nonobjc private var _statusValue: IG.Streamer.Subscription.Event
        /// Returns a subject subscribing to the subscription status.
        @nonobjc private let _statusSubject: PassthroughSubject<IG.Streamer.Subscription.Event,Never>
        /// The lock used to restrict access to the credentials.
        @nonobjc private let _lock: UnsafeMutablePointer<os_unfair_lock>
        
        /// Initializes a subscription which is not yet connected to the server.
        ///
        /// Each subscription will have its own serial `DispatchQueue`.
        /// - parameter mode: The Lightstreamer mode to use on subscription.
        /// - parameter item: The item being subscrbed to (e.g. "MARKET" or "ACCOUNT").
        /// - parameter fields: The properties/fields of the item being targeted for subscription.
        /// - parameter snapshot: Boolean indicating whether we need snapshot data.
        /// - parameter queue: The parent/channel dispatch queue.
        @nonobjc init(mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) {
            self._lock = UnsafeMutablePointer.allocate(capacity: 1)
            self._lock.initialize(to: os_unfair_lock())
            self._statusValue = .unsubscribed
            self._statusSubject = .init()
            
            self.item = item
            self.fields = fields
            self.lowlevel = LSSubscription(mode: mode.rawValue, item: item, fields: fields)
            self.lowlevel.requestedSnapshot = (snapshot) ? "yes" : "no"
            super.init()
            
            self.lowlevel.add(delegate: self)
        }
        
        deinit {
            assert(!self.lowlevel.isActive)
            self.lowlevel.remove(delegate: self)
        }
        
        /// Returns the current subscription status.
        @nonobjc final var status: IG.Streamer.Subscription.Event {
            os_unfair_lock_lock(self._lock)
            let currentStatus = self._statusValue
            os_unfair_lock_unlock(self._lock)
            return currentStatus
        }
        
        /// Subscribes to the subscription status events.
        ///
        /// This publisher removes duplicates (i.e. there aren't any repeating statuses).
        @nonobjc func subscribeToStatus(on queue: DispatchQueue) -> Publishers.ReceiveOn<PassthroughSubject<Streamer.Subscription.Event,Never>,DispatchQueue> {
            self._statusSubject.receive(on: queue)
        }
        
        /// Receives the low-level events and send them (or not) depending on whether the event is duplicated.
        /// - parameter status: The new status receive from the low-level handling layers.
        @nonobjc private final func _receive(_ status: IG.Streamer.Subscription.Event) {
            os_unfair_lock_lock(self._lock)
            let previousStatus = self._statusValue
            self._statusValue = status
            
            switch (previousStatus, status) {
            case (.subscribed, .subscribed), (.error, .error), (.unsubscribed, .unsubscribed):
                os_unfair_lock_unlock(self._lock)
            default:
                os_unfair_lock_unlock(self._lock)
                self._statusSubject.send(status)
            }
        }
    }
}

// MARK: - Lightstreamer Delegate

extension IG.Streamer.Subscription: LSSubscriptionDelegate {
    @objc func didSubscribe(to subscription: LSSubscription) {
        self._receive(.subscribed)
    }
    
    @objc func didUnsubscribe(from subscription: LSSubscription) {
        self._receive(.unsubscribed)
    }
    
    @objc func didFail(_ subscription: LSSubscription, errorCode code: Int, message: String?) {
        self._receive(.error(.init(code: code, message: message)))
    }
    
    @objc func didUpdate(_ subscription: LSSubscription, item itemUpdate: LSItemUpdate) {
        var result: IG.Streamer.Packet = .init(minimumCapacity: fields.count)
        for field in fields {
            let value = itemUpdate.value(withFieldName: field)
            result[field] = .init(value, isUpdated: itemUpdate.isValueChanged(withFieldName: field))
        }
        self._receive(.updateReceived(result))
    }
    
    @objc func didLoseUpdates(_ subscription: LSSubscription, count lostUpdates: UInt, itemName: String?, itemPosition itemPos: UInt) {
        self._receive(.updateLost(count: lostUpdates, item: itemName))
    }
    
//    @objc func didAddDelegate(to subscription: LSSubscription) {}
//    @objc func didRemoveDelegate(from subscription: LSSubscription) {}
//    @objc func subscription(_ subscription: LSSubscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {}
//    @objc func subscription(_ subscription: LSSubscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {}
}
