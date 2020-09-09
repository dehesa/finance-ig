#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#else
#error("OS currently not supported")
#endif
import Combine
import Conbini

internal extension Streamer {
    /// Streamer subscription publisher.
    struct Subscription: Publisher {
        typealias Output = LSItemUpdate
        typealias Failure = IG.Error
        
        /// The Lightstreamer low-level client; weakly held so to not produce retain cycles.
        weak var client: LSLightstreamerClient?
        /// The Lightstreamer mode used for this subscription.
        let mode: Streamer.Mode
        /// The Lightstreamer items to subscribe to.
        let items: [String]
        /// The targeted fields within the Lightstreamer item.
        let fields: [String]
        /// Boolean indicating whether the subscription will receive a first snapshot or not.
        let snapshot: Bool
        
        /// Designated initializer.
        init(client: LSLightstreamerClient, mode: Streamer.Mode, items: [String], fields: [String], snapshot: Bool) {
            precondition(!items.isEmpty && !fields.isEmpty)
            self.client = client
            self.mode = mode
            self.items = items
            self.fields = fields
            self.snapshot = snapshot
        }
        
        func receive<S>(subscriber: S) where S:Subscriber, S.Input==Output, S.Failure==Failure {
            guard let client = self.client else {
                return subscriber.receive(completion: .failure(._deallocatedInstance()))
            }
            
            let conduit = Conduit(downstream: subscriber, client: client, mode: self.mode, items: self.items, fields: self.fields, snapshot: self.snapshot)
            subscriber.receive(subscription: conduit)
        }
    }
}

fileprivate extension Streamer.Subscription {
    ///The shadow's subscription chain's origin.
    final class Conduit<Downstream>: NSObject, Subscription, LSSubscriptionDelegate where Downstream: Subscriber, Downstream.Input==Output, Downstream.Failure==Failure {
        /// Enum listing all possible conduit states.
        @ConduitLock private var state: ConduitState<Void,_Configuration>
        
        /// Designated initlalizer passing the state configuration values.
        @nonobjc init(downstream: Downstream, client: LSLightstreamerClient, mode: Streamer.Mode, items: [String], fields: [String], snapshot: Bool) {
            let subscription = LSSubscription(mode: mode.description, items: items, fields: fields)
            subscription.requestedSnapshot = (snapshot) ? "yes" : "no"
            
            self.state = .active(_Configuration(downstream: downstream, client: client, subscription: subscription, snapshot: snapshot))
            super.init()
            
            subscription.add(delegate: self)
        }
        
        deinit {
            if case .active(let config) = self._state.terminate() {
                if config.subscription.isActive { config.client.unsubscribe(config.subscription) }
                config.subscription.remove(delegate: self)
                config.downstream.receive(completion: .finished)
            }
            self._state.invalidate()
        }
        
        @nonobjc func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            
            self._state.lock()
            guard case .active(let config) = self._state.value else { return self._state.unlock() }
            config.demand += demand
            let (client, sub) = (config.client, config.subscription)
            self._state.unlock()
            
            guard !sub.isActive else { return }
            client.subscribe(sub)
        }
        
        @nonobjc func cancel() {
            guard case .active(let config) = self._state.terminate() else { return }
            if config.subscription.isActive { config.client.unsubscribe(config.subscription) }
            config.subscription.remove(delegate: self)
            
        }

        @objc func didFail(_ subscription: LSSubscription, errorCode code: Int, message: String?) {
            guard case .active(let config) = self._state.terminate() else { return }
            let error = IG.Error._failed(subscription: config.subscription, code: code, message: message)
            
            if config.subscription.isActive {
                config.client.unsubscribe(config.subscription)
            }
            config.subscription.remove(delegate: self)
            config.downstream.receive(completion: .failure(error))
        }

        @objc func didUpdate(_ subscription: LSSubscription, item itemUpdate: LSItemUpdate) {
            self._state.lock()
            // Observational experience has shown that the itemUpdate.isSnapshot always returns 'true".
            // It is unclear whether the problem is the Lightstreamer framework or the IG servers.
            guard let config = self._state.value.activeConfiguration, config.demand > 0
                  /*, config.snapshot || !itemUpdate.isSnapshot */ else { return self._state.unlock() }
            config.demand -= 1
            self._state.unlock()
            
            let demand = config.downstream.receive(itemUpdate)
            guard demand > 0 else { return }
            
            self._state.lock()
            guard case .active = self._state.value else { return self._state.unlock() }
            config.demand += demand
            self._state.unlock()
        }
        
//        @objc func didAddDelegate(to subscription: LSSubscription) {}
//        @objc func didRemoveDelegate(from subscription: LSSubscription) {}
//        @objc func didSubscribe(to subscription: LSSubscription) {}
//        @objc func didUnsubscribe(from subscription: LSSubscription) {}
//        @objc func didLoseUpdates(_ subscription: LSSubscription, count lostUpdates: UInt, itemName: String?, itemPosition itemPos: UInt) {}
//        @objc func subscription(_ subscription: LSSubscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {}
//        @objc func subscription(_ subscription: LSSubscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {}
    }
}

private extension Streamer.Subscription.Conduit {
    /// Values needed for the subscription active state.
    final class _Configuration {
        /// The downstream subscriber awaiting any value and/or completion events.
        let downstream: Downstream
        /// The low-level Lighstreamer client in charge of actually subscribing/unsubscribing.
        let client: LSLightstreamerClient
        /// The low-level Lighstreamer subscription.
        let subscription: LSSubscription
        /// The amount of values which can be sent downstream.
        var demand: Subscribers.Demand
        /// Boolean indicating whether a first snapshot was requested.
        let snapshot: Bool
        
        init(downstream: Downstream, client: LSLightstreamerClient, subscription: LSSubscription, snapshot: Bool) {
            self.downstream = downstream
            self.client = client
            self.subscription = subscription
            self.demand = .none
            self.snapshot = snapshot
        }
    }
}

private extension IG.Error {
    /// Error raised when the Streamer instance is deallocated.
    static func _deallocatedInstance() -> Self {
        Self(.streamer(.sessionExpired), "The \(Streamer.self) instance has been deallocated.", help: "The \(Streamer.self) functionality is asynchronous. Keep around the API instance while the request/response is being processed.")
    }
    /// Error raised when a subcription failure is provided by the subscription delegate.
    static func _failed(subscription: LSSubscription, code: Int, message: String?) -> Self {
        let (reason, help): (String, String)
        
        switch code {
        case ..<0: (reason, help) = ("The Metadata Adapter has refused the subscription or unsubscription request; the code value is dependent on the specific Metadata Adapter implementation.", "Contact IG.")
        case 17:   (reason, help) = ("Bad Data Adapter name or default Data Adapter not defined for the current Adapter Set.", "Contact the repo maintainer or IG.")
        case 20:   (reason, help) = ("Session interrupted", "Disconnect the streamer and start over.")
        case 21:   (reason, help) = ("Bad Group name.", "Contact the repo maintainer.")
        case 22:   (reason, help) = ("Bad Group name for this Schema.", "Check the subscription configuration or contact the repo maintainer.")
        case 23:   (reason, help) = ("Bad Schema name.", "Check the subscription configuration or contact the repo maintainer.")
        case 24:   (reason, help) = ("Mode not allowed for an Item.", "Check the subscription configuration or contact the repo maintainer.")
        case 25:   (reason, help) = ("Bad Selector name.", "Check the subscription configuration or contact the repo maintainer.")
        case 26:   (reason, help) = ("Unfiltered dispatching not allowed for an Item, because a frequency limit is associated to the item.", "Check the subscription configuration or contact the repo maintainer.")
        case 27:   (reason, help) = ("Unfiltered dispatching not supported for an Item, because a frequency prefiltering is applied for the item.", "Check the subscription configuration or contact the repo maintainer.")
        case 28:   (reason, help) = ("Unfiltered dispatching is not allowed by the current license terms (for special licenses only).", "Check the subscription configuration or contact the repo maintainer.")
        case 29:   (reason, help) = ("RAW mode is not allowed by the current license terms (for special licenses only).", "Check the subscription configuration or contact the repo maintainer.")
        case 30:   (reason, help) = ("Subscriptions are not allowed by the current license terms (for special licenses only)..", "Check the subscription configuration or contact the repo maintainer.")
        default:   (reason, help) = ("Unknown.", "Review the error code and the userInfo's server message (if any).")
        }
        
        var userInfo: [String:Any] = ["Code": code, "Mode": subscription.mode]
        
        if let message = message, !message.isEmpty {
            userInfo["Server message"] = message
        }
        
        if let array = subscription.items, !array.isEmpty, let items = array as? [String] {
            userInfo["Items"] = items
        }
        
        if let array = subscription.fields, !array.isEmpty, let fields = array as? [String] {
            userInfo["Fields"] = fields
        }
        
        if let string = subscription.requestedSnapshot {
            switch string.uppercased() {
            case "YES": userInfo["Snapshot"] = true
            case "NO":  userInfo["Snapshot"] = false
            default: break
            }
        }
        
        return Self(.streamer(.subscriptionFailed), reason, help: help, info: userInfo)
    }
}
