import ReactiveSwift
import Foundation

extension Streamer {
    /// Class handling the Lightstream subscriptions.
    internal class Subscription: NSObject {
        /// The queue where the data processing will be taking place.
        @nonobjc fileprivate let queue: DispatchQueue
        /// Private observer generating the values for the `events` signal.
        @nonobjc fileprivate let input: Signal<Event,Never>.Observer
        /// The Lightstreamer subcription instance.
        @nonobjc let session: StreamerSubscriptionSession
        /// All value frames returned by the server.
        @nonobjc let events: Signal<Event,Never>

        /// Designated initializer that creates the necessary overhead on top of subscription to handle the values reactively.
        /// - parameter subscription: The Lightstreamer internal subscription object.
        init(session: StreamerSubscriptionSession, queue: DispatchQueue) {
            self.queue = queue
            self.session = session
            (self.events, self.input) = Signal<Event,Never>.pipe()
            super.init()
            // Delegates are stored with weak references.
            self.session.add(delegate: self)
        }

        deinit {
            self.session.remove(delegate: self)
            self.input.sendCompleted()
        }

        /// Indicates whether the subscription is currently subscribed or not.
        @nonobjc var isSubscribed: Bool {
            return session.isSubscribed
        }

        /// Returns a list of all items targeted for subscription.
        @nonobjc var items: [String] {
            guard let objects = self.session.items,
                  let items = objects as? [String] else { return [] }
            return items
        }

        /// Returns a list of all fields targeted for subscription.
        @nonobjc var fields: [String] {
            guard let objects = self.session.fields,
                  let fields = objects as? [String] else { return [] }
            return fields
        }
    }
}

extension Streamer.Subscription: StreamerSubscriptionDelegate {
    @nonobjc func subscribed(to subscription: StreamerSubscriptionSession) {
        self.queue.async { [input = self.input] in
            input.send(value: .subscriptionSucceeded)
        }
    }
    
    @nonobjc func updateReceived(_ update: StreamerSubscriptionUpdate, from subscription: StreamerSubscriptionSession) {
        self.queue.async { [input = self.input] in
            input.send(value: .updateReceived(update))
        }
    }
    
    @nonobjc func updatesLost(count: UInt, from subscription: StreamerSubscriptionSession, item: (name: String?, position: UInt)) {
        self.queue.async { [input = self.input] in
            input.send(value: .updateLost(count: count, item: item.name))
        }
    }
    
    @nonobjc func subscriptionFailed(to subscription: StreamerSubscriptionSession, error: Streamer.Subscription.Error) {
        self.queue.async { [input = self.input] in
            input.send(value: .subscriptionFailed(error: error))
        }
    }
    
    @nonobjc func unsubscribed(to subscription: StreamerSubscriptionSession) {
        self.queue.async { [input = self.input] in
            input.send(value: .unsubscribed)
        }
    }
}

extension Streamer.Subscription {
    /// Events that can occur within a Streamer subscription.
    internal enum Event {
        /// A successful subscription is established.
        case subscriptionSucceeded
        /// A subscription couldn't be established.
        case subscriptionFailed(error: Streamer.Subscription.Error)
        /// An update has been received.
        case updateReceived(StreamerSubscriptionUpdate)
        /// Due to internal resource limitations, the server dropped `count` number of updates for the item name `item`.
        case updateLost(count: UInt, item: String?)
        /// The subscription was shut down successfully.
        case unsubscribed
    }
    
    /// Error raises when dealing with subscriptions lifecycle.
    internal struct Error: Swift.Error {
        /// The type of subscription error.
        let type: Kind
        /// The integer error code.
        let code: Int
        /// Optional explanation message.
        let message: String?
        
        init(code: Int, message: String?) {
            self.type = Kind(rawValue: code)
            self.code = code
            self.message = message
        }
        
        /// Error that can occur during the lifetime of a subscription.
        internal enum Kind {
            /// Unknown error (check error code for more information.
            case unknown
            /// Bad Data Adapter name or default Data Adapter not defined for the current Adapter Set.
            case invalidAdapterName
            /// Session interrupted.
            case interruptedSession
            /// Bad Group name.
            case invalidGroupName
            /// Bad Group name for this Schema.
            case invalidGroupNameForSchema
            /// Bad Schema name.
            case invalidSchemaName
            /// Mode not allowed for an Item.
            case prohibitedModeForItem
            /// Bad Selector name.
            case invalidSelectorName
            /// Unfiltered dispatching not allowed for an Item, because a frequency limit is associated to the item.
            case unfilteredDispatchingProhibited
            /// Unfiltered dispatching not supported for an Item, because a frequency prefiltering is applied for the item
            case unfilteredDispatchingUnsupported
            /// Unfiltered dispatching is not allowed by the current license terms (for special licenses only)
            case unfilteredDispatchingRestricted
            /// RAW mode is not allowed by the current license terms (for special licenses only)
            case rawModeRestricted
            /// Subscriptions are not allowed by the current license terms (for special licenses only).
            case subscriptionRestricted
            /// The Metadata Adapter has refused the subscription or unsubscription request; the code value is dependent on the specific Metadata Adapter implementation
            case requestRefused
            
            init(rawValue: Int) {
                switch rawValue {
                case ..<0: self = .requestRefused
                case 17:   self = .invalidAdapterName
                case 20:   self = .interruptedSession
                case 21:   self = .invalidGroupName
                case 22:   self = .invalidGroupNameForSchema
                case 23:   self = .invalidSchemaName
                case 24:   self = .prohibitedModeForItem
                case 25:   self = .invalidSelectorName
                case 26:   self = .unfilteredDispatchingProhibited
                case 27:   self = .unfilteredDispatchingUnsupported
                case 28:   self = .unfilteredDispatchingRestricted
                case 29:   self = .rawModeRestricted
                case 30:   self = .subscriptionRestricted
                default:   self = .unknown
                }
            }
        }
    }
}
