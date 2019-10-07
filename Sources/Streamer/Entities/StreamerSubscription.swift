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
        
        /// `CurrentValueSubject` managing the current channel status and its publisher.
        ///
        /// This subject may publish duplicates and it always returns the current status upon activation.
        /// - important: This publisher returns values on the Lightstreamer low-level queue. Change queues as soon as possible to let the low-level layers continue processing incoming network pacakges.
        @nonobjc private let mutableStatus: CurrentValueSubject<IG.Streamer.Subscription.Event,Never>
        
        /// Initializes a subscription which is not yet connected to the server.
        ///
        /// Each subscription will have its own serial `DispatchQueue`.
        /// - parameter mode: The Lightstreamer mode to use on subscription.
        /// - parameter item: The item being subscrbed to (e.g. "MARKET" or "ACCOUNT").
        /// - parameter fields: The properties/fields of the item being targeted for subscription.
        /// - parameter snapshot: Boolean indicating whether we need snapshot data.
        /// - parameter queue: The parent/channel dispatch queue.
        @nonobjc init(mode: IG.Streamer.Mode, item: String, fields: [String], snapshot: Bool) {
            self.mutableStatus = .init(.unsubscribed)
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
        
        /// Returns a publisher to subscribe to status events (the current value is sent first).
        ///
        /// This publisher remove duplicates (i.e. there aren't any repeating statuses) and it always returns the current status upon activation.
        /// - important: This publisher returns values on the Lightstreamer low-level queue. Change queues as soon as possible to let the low-level layers continue processing incoming network pacakges.
        @nonobjc final var status: some CurrentEventPublisher {
            return self.mutableStatus
        }
        
        private final func receive(_ status: IG.Streamer.Subscription.Event) {
            switch (self.mutableStatus.value, status) {
            case (.subscribed, .subscribed), (.error, .error), (.unsubscribed, .unsubscribed): break
            default: self.mutableStatus.send(status)
            }
        }
    }
}

// MARK: - Lightstreamer Delegate

extension IG.Streamer.Subscription: LSSubscriptionDelegate {
    @objc func didSubscribe(to subscription: LSSubscription) {
        self.receive(.subscribed)
    }
    
    @objc func didUnsubscribe(from subscription: LSSubscription) {
        self.receive(.unsubscribed)
    }
    
    @objc func didFail(_ subscription: LSSubscription, errorCode code: Int, message: String?) {
        self.receive(.error(.init(code: code, message: message)))
    }
    
    @objc func didUpdate(_ subscription: LSSubscription, item itemUpdate: LSItemUpdate) {
        var result: [String:IG.Streamer.Subscription.Update] = .init(minimumCapacity: fields.count)
        for field in fields {
            let value = itemUpdate.value(withFieldName: field)
            result[field] = .init(value, isUpdated: itemUpdate.isValueChanged(withFieldName: field))
        }
        self.receive(.updateReceived(result))
    }
    
    @objc func didLoseUpdates(_ subscription: LSSubscription, count lostUpdates: UInt, itemName: String?, itemPosition itemPos: UInt) {
        self.receive(.updateLost(count: lostUpdates, item: itemName))
    }
//    @objc func didAddDelegate(to subscription: LSSubscription) {}
//    @objc func didRemoveDelegate(from subscription: LSSubscription) {}
//    @objc func subscription(_ subscription: LSSubscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {}
//    @objc func subscription(_ subscription: LSSubscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {}
}

// MARK: - Combine Extensions

/// Returns the receiving's publisher current value.
internal protocol CurrentEventPublisher: Publisher where Output==IG.Streamer.Subscription.Event, Failure==Never {
    /// The value wrapped by this subject, published as a new element whenever it changes.
    var value: Output { get }
}

extension CurrentValueSubject: CurrentEventPublisher where Output==IG.Streamer.Subscription.Event, Failure==Never {}
