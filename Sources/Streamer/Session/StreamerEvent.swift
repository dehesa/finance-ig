import Lightstreamer_macOS_Client
import Foundation

extension Streamer.Subscription {
    /// Events that can occur within a Streamer subscription.
    internal enum Event {
        /// A successful subscription is established.
        case subscriptionSucceeded
        /// A subscription couldn't be established.
        case subscriptionFailed(error: Streamer.Subscription.Error)
        /// An update has been received.
        case updateReceived(LSItemUpdate)
        /// Due to internal resource limitations, the server dropped `count` number of updates for the item name `item`.
        case updateLost(count: UInt, item: String?)
        /// The subscription was shut down successfully.
        case unsubscribed
    }
}

extension Streamer.Subscription {
    /// Error that can occur during the lifetime of a subscription.
    internal struct Error: Swift.Error, CustomDebugStringConvertible {
        /// The type of subscription error.
        let kind: Self.Kind
        /// The integer error code.
        let code: Int
        /// Optional explanation of what happened.
        let message: String?
        
        init(code: Int, message: String?) {
            self.code = code
            self.message = message
            self.kind = .init(rawValue: code)
        }
        
        var debugDescription: String {
            var result = ErrorPrint(domain: "Streamer Subscription Error", title: "Code \(self.code) - \(self.kind.debugDescription)")
            result.append(details: self.message)
            return result.debugDescription
        }
    }
}

extension Streamer.Subscription.Error {
    /// The type of a subscription error.
    internal enum Kind: CustomDebugStringConvertible {
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
        
        var debugDescription: String {
            switch self {
            case .unknown: return "Unknown error."
            case .invalidAdapterName: return "Bad Data Adapter name or default Data Adapter not defined for the current Adapter Set."
            case .interruptedSession: return "Session interrupted."
            case .invalidGroupName: return "Bad Group name."
            case .invalidGroupNameForSchema: return "Bad Group name for this Schema."
            case .invalidSchemaName: return "Bad Schema name."
            case .prohibitedModeForItem: return "Mode not allowed for an Item."
            case .invalidSelectorName: return "Bad Selector name."
            case .unfilteredDispatchingProhibited: return "Unfiltered dispatching not allowed for an Item, because a frequency limit is associated to the item."
            case .unfilteredDispatchingUnsupported: return "Unfiltered dispatching not supported for an Item, because a frequency prefiltering is applied for the item."
            case .unfilteredDispatchingRestricted: return "Unfiltered dispatching is not allowed by the current license terms (for special licenses only)."
            case .rawModeRestricted: return "RAW mode is not allowed by the current license terms (for special licenses only)."
            case .subscriptionRestricted: return "Subscriptions are not allowed by the current license terms (for special licenses only)."
            case .requestRefused: return "The Metadata Adapter has refused the subscription or unsubscription request; the code value is dependent on the specific Metadata Adapter implementation."
            }
        }
    }
}

