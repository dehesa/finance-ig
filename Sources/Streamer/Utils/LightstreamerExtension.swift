import Lightstreamer_macOS_Client
import Foundation

//// Added so `LSSubscription` can support the level of indirection needed for the mocking harness.
//extension LSSubscription: StreamerSubscriptionSession {
//    @nonobjc func add(delegate: StreamerSubscriptionDelegate) {
//        self.addDelegate(delegate as! LSSubscriptionDelegate)
//    }
//
//    @nonobjc func remove(delegate: StreamerSubscriptionDelegate) {
//        self.removeDelegate(delegate as! LSSubscriptionDelegate)
//    }
//}
//
//// Added so `LSItemUpdate` can support the level of indirection needed for the mocking harness.
//extension LSItemUpdate: StreamerSubscriptionUpdate {
//    @nonobjc var item: String {
//        return self.itemName!
//    }
//
//    @nonobjc var all: [String:String] {
//        return self.fields as! [String:String]
//    }
//
//    @nonobjc var latest: [String:String] {
//        return self.changedFields as! [String:String]
//    }
//}
