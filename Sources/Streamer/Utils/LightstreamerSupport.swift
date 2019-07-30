import Lightstreamer_macOS_Client
import Foundation

//extension Streamer.Response.Update {
//    /// Designated way to create an update structure.
//    /// - throws: `Streamer.Error.invalidResponse(...)` exclusively.
//    internal static func make(_ update: StreamerSubscriptionUpdate) throws -> (parsed: [Field:String], update: Streamer.Response.Update<Field>) {
//        let (fields, delta): ([String:String], Dictionary<String,Any>.Keys)
//
//        // Look for all the fields' keys and values, and the delta keys.
//        if let package = update as? LSItemUpdate {
//            guard let f = package.fields as? [String:String] else {
//                throw Streamer.Error.invalidResponse(item: package.itemName, fields: package.fields, message: "The Lightstreamer update package couldn't be parsed to [String:String].")
//            }
//
//            guard let d = (package.changedFields as? [String:Any])?.keys else {
//                throw Streamer.Error.invalidResponse(item: package.itemName, fields: package.fields, message: "The Lightstreamer update delta fields couldn't be parsed.")
//            }
//
//            (fields, delta) = (f, d)
//        } else {
//            (fields, delta) = (update.all, (update.latest as [String:Any]).keys)
//        }
//
//        /// The key/value pairs for all fields in the update (whether changed or not).
//        var r = Dictionary<Field,String>(minimumCapacity: fields.count)
//        for (key, value) in fields {
//            guard let attribute = Field(rawValue: key) else {
//                throw Streamer.Error.invalidResponse(item: update.item, fields: fields, message: "The Lightstreamer field name \"\(key)\" couldn't be parsed.")
//            }
//            r[attribute] = value
//        }
//
//        /// The names for the fields that changed value since last update.
//        var d = Set<Field>(minimumCapacity: delta.count)
//        for string in delta {
//            guard let attribute = Field(rawValue: string) else { continue }
//            d.insert(attribute)
//        }
//
//        return (r, .init(received: Set(r.keys), delta: d))
//    }
//}
//
//// Extension added to support obj-c `LSSubscriptionDelegate` methods by `Streamer.Subscription` instances.
//extension Streamer.Subscription: LSSubscriptionDelegate {
//    @objc func subscriptionDidSubscribe(_ subscription: LSSubscription) {
//        self.subscribed(to: subscription)
//    }
//
//    @objc func subscription(_ subscription: LSSubscription, didUpdateItem itemUpdate: LSItemUpdate) {
//        self.updateReceived(itemUpdate, from: subscription)
//    }
//
//    @objc func subscription(_ subscription: LSSubscription, didLoseUpdates lostUpdates: UInt, forItemName itemName: String?, itemPos: UInt) {
//        self.updatesLost(count: lostUpdates, from: subscription, item: (itemName, itemPos))
//    }
//
//    @objc func subscription(_ subscription: LSSubscription, didFailWithErrorCode code: Int, message: String?) {
//        let error = Streamer.Subscription.Error(code: code, message: message)
//        self.subscriptionFailed(to: subscription, error: error)
//    }
//
//    @objc func subscriptionDidUnsubscribe(_ subscription: LSSubscription) {
//        self.unsubscribed(to: subscription)
//    }
//}
