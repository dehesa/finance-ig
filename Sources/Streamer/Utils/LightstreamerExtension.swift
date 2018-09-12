import Lightstreamer_macOS_Client
import Foundation

// Added so `LSSubscription` can support the level of indirection needed for the mocking harness.
extension LSSubscription: StreamerSubscriptionSession {
    @nonobjc func add(delegate: StreamerSubscriptionDelegate) {
        self.addDelegate(delegate as! LSSubscriptionDelegate)
    }
    
    @nonobjc func remove(delegate: StreamerSubscriptionDelegate) {
        self.removeDelegate(delegate as! LSSubscriptionDelegate)
    }
}

// Added so `LSLightstreamerClient` can support the level of indirection needed for the mocking harness.
extension LSLightstreamerClient: StreamerSession {
    @nonobjc func add(delegate: StreamerSessionDelegate) {
        self.addDelegate(delegate as! LSClientDelegate)
    }
    
    @nonobjc func remove(delegate: StreamerSessionDelegate) {
        self.removeDelegate(delegate as! LSClientDelegate)
    }
    
    @nonobjc func subscribe(to subscription: StreamerSubscriptionSession) {
        self.subscribe(subscription as! LSSubscription)
    }
    
    @nonobjc func unsubscribe(from subscription: StreamerSubscriptionSession) {
        self.unsubscribe(subscription as! LSSubscription)
    }
    
    @nonobjc func makeSubscriptionSession<F:StreamerField>(mode: Streamer.Mode, items: Set<String>, fields: Set<F>) -> StreamerSubscriptionSession {
        if items.count == 1 {
            return LSSubscription(subscriptionMode: mode.rawValue, item: items.first!, fields: fields.map { $0.rawValue })
        } else {
            return LSSubscription(subscriptionMode: mode.rawValue, items: Array(items), fields: fields.map { $0.rawValue })
        }
    }
}

// Added so `LSItemUpdate` can support the level of indirection needed for the mocking harness.
extension LSItemUpdate: StreamerSubscriptionUpdate {
    @nonobjc var item: String {
        return self.itemName!
    }
    
    @nonobjc var all: [String:String] {
        return self.fields as! [String:String]
    }
    
    @nonobjc var latest: [String:String] {
        return self.changedFields as! [String:String]
    }
}
