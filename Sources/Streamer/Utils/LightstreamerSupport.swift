import Lightstreamer_macOS_Client
import Foundation

// Extension added to support `LSLightstreamerClient` sessions on `Streamer` instances.
extension Streamer {
    /// Creates a `Streamer` instance with the provided credentails and start it right away.
    ///
    /// If you set `autoconnect` to `false` you don't have to forget to call `connect` on the returned instance.
    /// - parameter rootURL: The URL where the streaming server is located.
    /// - parameter credentails: Priviledge credentials permitting the creation of streaming channels.
    /// - parameter autoconnect: Boolean indicating whether the `connect()` function is called right away, or whether it shall be called later on by the user.
    public convenience init(rootURL: URL, credentials: Streamer.Credentials, autoconnect: Bool = true) {
        let session = LSLightstreamerClient(serverAddress: rootURL.absoluteString, adapterSet: nil).set { (client) in
            client.connectionDetails.user = credentials.identifier
            client.connectionDetails.setPassword(credentials.password)
        }
        self.init(rootURL: rootURL, session: session, autoconnect: autoconnect)
    }
}

// Extension added to support obj-c `LSClientDelegate` methods by `StreamerSessionObserver` instances.
extension StreamerSessionObserver: LSClientDelegate {
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        guard let result = Streamer.Status(rawValue: status) else {
            fatalError("Lightstreamer client status \"\(status)\" was not recognized.")
        }
        self.statusChanged(to: result, on: client)
    }
}

extension Streamer.Response.Update {
    /// Designated way to create an update structure.
    /// - throws: `Streamer.Error.invalidResponse(...)` exclusively.
    internal static func make(_ update: StreamerSubscriptionUpdate) throws -> (parsed: [Field:String], update: Streamer.Response.Update<Field>) {
        let (fields, delta): ([String:String], Dictionary<String,Any>.Keys)
        
        // Look for all the fields' keys and values, and the delta keys.
        if let package = update as? LSItemUpdate {
            guard let f = package.fields as? [String:String] else {
                throw Streamer.Error.invalidResponse(item: package.itemName, fields: package.fields, message: "The Lightstreamer update package couldn't be parsed to [String:String].")
            }
            
            guard let d = (package.changedFields as? [String:Any])?.keys else {
                throw Streamer.Error.invalidResponse(item: package.itemName, fields: package.fields, message: "The Lightstreamer update delta fields couldn't be parsed.")
            }
            
            (fields, delta) = (f, d)
        } else {
            (fields, delta) = (update.all, (update.latest as [String:Any]).keys)
        }
        
        /// The key/value pairs for all fields in the update (whether changed or not).
        var r = Dictionary<Field,String>(minimumCapacity: fields.count)
        for (key, value) in fields {
            guard let attribute = Field(rawValue: key) else {
                throw Streamer.Error.invalidResponse(item: update.item, fields: fields, message: "The Lightstreamer field name \"\(key)\" couldn't be parsed.")
            }
            r[attribute] = value
        }
        
        /// The names for the fields that changed value since last update.
        var d = Set<Field>(minimumCapacity: delta.count)
        for string in delta {
            guard let attribute = Field(rawValue: string) else { continue }
            d.insert(attribute)
        }
        
        return (r, .init(received: Set(r.keys), delta: d))
    }
}

// Extension added to support obj-c `LSSubscriptionDelegate` methods by `Streamer.Subscription` instances.
extension Streamer.Subscription: LSSubscriptionDelegate {
    @objc func subscriptionDidSubscribe(_ subscription: LSSubscription) {
        self.subscribed(to: subscription)
    }
    
    @objc func subscription(_ subscription: LSSubscription, didUpdateItem itemUpdate: LSItemUpdate) {
        self.updateReceived(itemUpdate, from: subscription)
    }
    
    @objc func subscription(_ subscription: LSSubscription, didLoseUpdates lostUpdates: UInt, forItemName itemName: String?, itemPos: UInt) {
        self.updatesLost(count: lostUpdates, from: subscription, item: (itemName, itemPos))
    }
    
    @objc func subscription(_ subscription: LSSubscription, didFailWithErrorCode code: Int, message: String?) {
        let error = Streamer.Subscription.Error(code: code, message: message)
        self.subscriptionFailed(to: subscription, error: error)
    }
    
    @objc func subscriptionDidUnsubscribe(_ subscription: LSSubscription) {
        self.unsubscribed(to: subscription)
    }
}
