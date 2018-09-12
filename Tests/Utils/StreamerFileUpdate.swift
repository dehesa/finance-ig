@testable import IG
import Utils
import ReactiveSwift
import Result
import Foundation

extension StreamerFileSession {
    /// An update within a File Stream Subscription.
    ///
    /// A subscription will return (hopefully) many different updates.
    final class SubscriptionUpdate: StreamerSubscriptionUpdate {
        let item: String
        let isSnapshot: Bool
        let all: [String:String]
        let latest: [String:String]
        
        /// Initializes an update with the data of a file.
        /// - parameter item: The name of the item being subscribed.
        /// - parameter snapshot: Whether this update is a "snapshot" update or not.
        /// - parameter fields: Key/Values received for this update.
        /// - parameter previous: The exactly previous update before this one.
        convenience init(item: String, snapshot: Bool, fields: [String:String], previous: SubscriptionUpdate?) {
            if snapshot {
                self.init(item: item, snapshot: fields)
            } else {
                self.init(item: item, update: fields, previous: previous)
            }
        }
        
        /// Initializes a snapshot update with the data of a file.
        /// - parameter item: The name of the item being subscribed.
        /// - parameter snapshot: Key/Values for all fields in the subscription.
        init(item: String, snapshot: [String:String]) {
            self.item = item
            self.isSnapshot = true
            self.all = snapshot
            self.latest = self.all
        }
        
        /// Initializes a non-snapshot update with the data of a file.
        /// - parameter item: The name of the item being subscribed.
        /// - parameter update: The key/values updated in this update event.
        /// - parameter previous: The exactly previous update before this one.
        init(item: String, update: [String:String], previous: SubscriptionUpdate?) {
            self.item = item
            self.isSnapshot = false
            self.latest = update
            
            if let previous = previous {
                var all = previous.all
                for (key, value) in self.latest {
                    all[key] = value
                }
                self.all = all
            } else {
                self.all = self.latest
            }
        }
    }
}
