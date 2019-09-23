#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#else
#error("OS currently not supported")
#endif
import Foundation

extension IG.Streamer.Subscription {
    /// Events that can occur within a Streamer subscription.
    internal enum Event: Equatable {
        /// A successful subscription is established.
        case subscribed
        /// The subscription was shut down successfully.
        case unsubscribed
        /// An update has been received.
        case updateReceived([String:IG.Streamer.Subscription.Update])
        /// Due to internal resource limitations, the server dropped `count` number of updates for the item name `item`.
        case updateLost(count: UInt, item: String?)
        /// There was an error during the subscription/unsubscription process.
        case error(IG.Streamer.Subscription.Error)
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.subscribed, .subscribed), (.unsubscribed, .unsubscribed):
                return true
            case (.error(let l), .error(let r)):
                return l == r
            case (.updateLost(let lc, let li), .updateLost(let rc, let ri)):
                return (lc == rc) && (li == ri)
            default: return false
            }
        }
    }
}

extension IG.Streamer.Subscription {
    /// A single field update.
    internal struct Update {
        /// Whether the field has been updated since the last udpate.
        let isUpdated: Bool
        /// The latest value.
        let value: String?
        /// Designated initializer.
        init(_ value: String?, isUpdated: Bool) {
            self.value = value
            self.isUpdated = isUpdated
        }
    }
}

extension IG.Streamer.Subscription {
    /// Error that can occur during the lifetime of a subscription.
    internal struct Error: Swift.Error, Equatable {
        /// The type of subscription error.
        let type: Self.Kind
        /// The integer error code.
        let code: Int
        /// Optional explanation of what happened.
        let message: String?
        
        init(code: Int, message: String?) {
            self.code = code
            self.message = message
            self.type = .init(rawValue: code)
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.code == rhs.code
        }
    }
}

extension IG.Streamer.Subscription.Error: IG.ErrorPrintable {
    static var printableDomain: String {
        return "IG.\(IG.Streamer.self).\(IG.Streamer.Subscription.self).\(IG.Streamer.Subscription.Error.self)"
    }
    
    var printableType: String {
        switch self.type {
        case .unknown: return "Unknown"
        case .invalidAdapterName: return "Invalid adapter name"
        case .interruptedSession: return "Interrupt session"
        case .invalidGroupName: return "Invalid group name"
        case .invalidGroupNameForSchema: return "Invalid group name for schema"
        case .invalidSchemaName: return "Invalid schema name"
        case .prohibitedModeForItem: return "Prohibit mode for item"
        case .invalidSelectorName: return "Invalid selector name"
        case .unfilteredDispatchingProhibited: return "Unfiltered dispatching prohibited"
        case .unfilteredDispatchingUnsupported: return "Unfilter dispatching unsupported"
        case .unfilteredDispatchingRestricted: return "Unfiltered dispatching restricted"
        case .rawModeRestricted: return "Raw mode restricted"
        case .subscriptionRestricted: return "Subscription restricted"
        case .requestRefused: return "Request refused"
        }
    }
    
    func printableMultiline(level: Int) -> String {
        let levelPrefix = Self.debugPrefix(level: level+1)
        
        var result = "\(Self.printableDomain) (\(self.code) -> \(self.printableType))"
        result.append("\(levelPrefix)Type description: \(self.type.debugDescription)")
        if let message = self.message {
            result.append("\(levelPrefix)Error message: \(message)")
        }
        return result
    }
}

extension IG.Streamer.Subscription.Error {
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
            case .unknown: return "Unknown error"
            case .invalidAdapterName: return "Bad Data Adapter name or default Data Adapter not defined for the current Adapter Set"
            case .interruptedSession: return "Session interrupted"
            case .invalidGroupName: return "Bad Group name"
            case .invalidGroupNameForSchema: return "Bad Group name for this Schema"
            case .invalidSchemaName: return "Bad Schema name"
            case .prohibitedModeForItem: return "Mode not allowed for an Item"
            case .invalidSelectorName: return "Bad Selector name"
            case .unfilteredDispatchingProhibited: return "Unfiltered dispatching not allowed for an Item, because a frequency limit is associated to the item"
            case .unfilteredDispatchingUnsupported: return "Unfiltered dispatching not supported for an Item, because a frequency prefiltering is applied for the item"
            case .unfilteredDispatchingRestricted: return "Unfiltered dispatching is not allowed by the current license terms (for special licenses only)"
            case .rawModeRestricted: return "RAW mode is not allowed by the current license terms (for special licenses only)"
            case .subscriptionRestricted: return "Subscriptions are not allowed by the current license terms (for special licenses only)"
            case .requestRefused: return "The Metadata Adapter has refused the subscription or unsubscription request; the code value is dependent on the specific Metadata Adapter implementation"
            }
        }
    }
}
