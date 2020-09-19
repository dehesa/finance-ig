import Foundation
import Decimals

extension API {
    /// A trading activity on the given account.
    public struct Activity: Identifiable {
        /// The date of the activity item.
        public let date: Date
        /// Deal identifier.
        public let id: IG.Deal.Identifier
        /// Activity description.
        public let summary: String
        /// Activity type.
        public let type: Self.Kind
        /// Action status.
        public let status: Self.Status
        /// The channel which triggered the activity.
        public let channel: Self.Channel
        /// Instrument epic identifier.
        public let epic: IG.Market.Epic
        /// The period of the activity item.
        public let expiry: IG.Market.Expiry
        /// Activity details.
        public let details: Self.Details?
    }
}

extension API.Activity {
    /// Activity Type.
    public enum Kind: Hashable {
        /// System generated activity.
        case system
        /// Position activity.
        case position
        /// Working order activity.
        case workingOrder
        /// Amend stop or limit activity.
        case amended
    }
    
    /// Activity status.
    public enum Status: Hashable {
        /// The activity has been accepted.
        case accepted
        /// The activity has been rejected.
        case rejected
        /// The activity status is unknown.
        case unknown
    }
    
    /// Trigger channel.
    public enum Channel: Hashable {
        /// Activity performed through the platform's internal system.
        case system
        /// Activity performed through the platform's website.
        case web
        /// Activity performed through the mobile app.
        case mobile
        /// Activity performed through the API.
        case api
        /// Activity performed through an outside dealer.
        case dealer
        /// Activity performed through the financial FIX system.
        case fix
    }
    
    /// Further details of the targeted activity.
    public struct Details {
        /// Transient deal reference for an unconfirmed trade.
        public let reference : IG.Deal.Reference?
        /// Deal affected by an activity.
        public let actions: [API.Activity.Action]
        /// A financial market, which may refer to an underlying financial market, or the market being offered in terms of an IG instrument. IG instruments are organised in the form a navigable market hierarchy.
        public let marketName: String
        /// The currency denomination.
        public let currency: Currency.Code
        /// Deal direction.
        public let direction: IG.Deal.Direction
        /// Deal size.
        public let size: Decimal64
        /// Instrument price at which the activity has been "commited"
        public let level: Decimal64
        /// Level at which the user is happy to take profit.
        public let limit: (level: Decimal64, distance: Decimal64)?
        /// Stop for the targeted deal
        public let stop: (level: Decimal64, distance: Decimal64, risk: IG.Deal.Stop.Risk, trailing: IG.Deal.Stop.TrailingData)?
        /// Working order expiration.
        ///
        /// If the activity doesn't reference a working order, this property will be `nil`.
        public let workingOrderExpiration: IG.Deal.WorkingOrder.Expiration?
    }
}

extension API.Activity {
    /// Deal affected by an activity.
    public struct Action {
        /// Action type.
        public let type: Self.Kind
        /// Affected deal identifier.
        public let dealId: IG.Deal.Identifier
        
        /// The action type.
        ///
        /// Refects who is the receiver of the action on what status has been changed to.
        public enum Kind: Hashable {
            /// The action affects a position and its status has been modified to the one given here.
            case position(status: API.Activity.Action.PositionStatus)
            /// The action affects a working order and its status has been modified to the one given here.
            case workingOrder(status: API.Activity.Action.WorkingOrderStatus, type: IG.Deal.WorkingOrder?)
            /// A deal's stop and/or limit has been amended.
            case dealStopLimitAmended
            /// The action is of unknown character.
            case unknown
        }
        
        /// Position's action status.
        public enum PositionStatus: Hashable {
            case opened
            case rolled
            case closed(Self.Completion)
            case deleted
            
            public enum Completion: Hashable {
                case partially
                case fully
            }
        }
        
        /// Working order's action status.
        public enum WorkingOrderStatus: Hashable {
            case opened
            case amended
            case rolled
            case filled
            case deleted
        }
    }
}

// MARK: -

extension API.Activity: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        let formatter = try decoder.userInfo[API.JSON.DecoderKey.computedValues] as? DateFormatter ?> DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "No DateFormatter was found on the decoder's userInfo.")
        self.date = try container.decode(Date.self, forKey: .date, with: formatter)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.type = try container.decode(Self.Kind.self, forKey: .type)
        self.status = try container.decode(Self.Status.self, forKey: .status)
        self.channel = try container.decode(Self.Channel.self, forKey: .channel)
        self.id = try container.decode(IG.Deal.Identifier.self, forKey: .id)
        self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
        self.expiry = try container.decodeIfPresent(IG.Market.Expiry.self, forKey: .expiry) ?? .none
        self.details = try container.decodeIfPresent(Self.Details.self, forKey: .details)
    }
    
    private enum _Keys: String, CodingKey {
        case date, id = "dealId"
        case summary = "description"
        case type, status, channel
        case epic, expiry = "period"
        case details
    }
}

extension API.Activity.Kind: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "SYSTEM": self = .system
        case "POSITION": self = .position
        case "WORKING_ORDER": self = .workingOrder
        case "EDIT_STOP_AND_LIMIT": self = .amended
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid activity type '\(value)'.")
        }
    }
}

extension API.Activity.Status: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "ACCEPTED": self = .accepted
        case "REJECTED": self = .rejected
        case "UNKNOWN":  self = .unknown
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid activity status '\(value)'.")
        }
    }
}

extension API.Activity.Channel: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "SYSTEM": self = .system
        case "WEB": self = .web
        case "MOBILE": self = .mobile
        case "PUBLIC_WEB_API": self = .api
        case "DEALER": self = .dealer
        case "PUBLIC_FIX_API": self = .fix
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid activity channel '\(value)'.")
        }
    }
}

extension API.Activity.Details: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.reference = try container.decodeIfPresent(IG.Deal.Reference.self, forKey: .reference)
        self.actions = try container.decode([API.Activity.Action].self, forKey: .actions)
        self.marketName = try container.decode(String.self, forKey: .marketName)
        self.currency = try container.decode(Currency.Code.self, forKey: .currency)
        self.direction = try container.decode(IG.Deal.Direction.self, forKey: .direction)
        self.size = try container.decode(Decimal64.self, forKey: .size)
        self.level = try container.decode(Decimal64.self, forKey: .level)
        
        switch (try container.decodeIfPresent(Decimal64.self, forKey: .limitLevel), try container.decodeIfPresent(Decimal64.self, forKey: .limitDistance)) {
        case (.none, .none): self.limit = nil
        case (let l?, let d?): self.limit = (l, d)
        default: throw DecodingError.dataCorruptedError(forKey: .limitLevel, in: container, debugDescription: "Invalid limit.")
        }
        
        if let stopLevel = try container.decodeIfPresent(Decimal64.self, forKey: .stopLevel), let stopDistance = try container.decodeIfPresent(Decimal64.self, forKey: .stopDistance) {
            let risk: IG.Deal.Stop.Risk = (try container.decode(Bool.self, forKey: .isStopGuaranteed)) ? .limited : .exposed
            switch (try container.decodeIfPresent(Decimal64.self, forKey: .stopTrailingDistance), try container.decodeIfPresent(Decimal64.self, forKey: .stopTrailingIncrement)) {
            case (.none, .none): self.stop = (stopLevel, stopDistance, risk, .static)
            case (let d?, let i?): self.stop = (stopLevel, stopDistance, risk, .dynamic(distance: d, increment: i))
            default: throw DecodingError.dataCorruptedError(forKey: .stopTrailingDistance, in: container, debugDescription: "Invalid trailing stop.")
            }
        } else { self.stop = nil }
        
        if let expiration = try container.decodeIfPresent(String.self, forKey: .expiration) {
            switch expiration {
            case "GTC": self.workingOrderExpiration = .tillCancelled
            case let value:
                guard let formatter = decoder.userInfo[API.JSON.DecoderKey.computedValues] as? DateFormatter else {
                    throw DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: "No DateFormatter was found on the decoder's userInfo.")
                }
                let date = try formatter.date(from: value) ?> DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: formatter.parseErrorLine(date: value))
                self.workingOrderExpiration = .tillDate(date)
            }
        } else { self.workingOrderExpiration = nil }
    }
    
    private enum _Keys: String, CodingKey {
        case reference = "dealReference", actions
        case currency
        case direction, marketName, size
        case level, limitLevel, limitDistance
        case stopLevel, stopDistance, isStopGuaranteed = "guaranteedStop"
        case stopTrailingDistance = "trailingStopDistance", stopTrailingIncrement = "trailingStep"
        case expiration = "goodTillDate"
    }
}

extension API.Activity.Action: Decodable {
    /// Do not call! The only way to initialize is through `Decodable`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.dealId = try container.decode(IG.Deal.Identifier.self, forKey: .dealId)
        
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "STOP_LIMIT_AMENDED":  self.type = .dealStopLimitAmended
        case "POSITION_OPENED":     self.type = .position(status: .opened)
        case "POSITION_ROLLED":     self.type = .position(status: .rolled)
        case "POSITION_PARTIALLY_CLOSED": self.type = .position(status: .closed(.partially))
        case "POSITION_CLOSED":     self.type = .position(status: .closed(.fully))
        case "POSITION_DELETED":    self.type = .position(status: .deleted)
        case "LIMIT_ORDER_OPENED":  self.type = .workingOrder(status: .opened, type: .limit)
        case "LIMIT_ORDER_FILLED":  self.type = .workingOrder(status: .filled, type: .limit)
        case "LIMIT_ORDER_AMENDED": self.type = .workingOrder(status: .amended, type: .limit)
        case "LIMIT_ORDER_ROLLED":  self.type = .workingOrder(status: .rolled, type: .limit)
        case "LIMIT_ORDER_DELETED": self.type = .workingOrder(status: .deleted, type: .limit)
        case "STOP_ORDER_OPENED":   self.type = .workingOrder(status: .opened, type: .stop)
        case "STOP_ORDER_FILLED":   self.type = .workingOrder(status: .filled, type: .stop)
        case "STOP_ORDER_AMENDED":  self.type = .workingOrder(status: .amended, type: .stop)
        case "STOP_ORDER_ROLLED":   self.type = .workingOrder(status: .rolled, type: .stop)
        case "STOP_ORDER_DELETED":  self.type = .workingOrder(status: .deleted, type: .stop)
        case "WORKING_ORDER_DELETED": self.type = .workingOrder(status: .deleted, type: nil)
        case "UNKNOWN":             self.type = .unknown
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid action type '\(type)'.")
        }
    }
    
    private enum _Keys: String, CodingKey {
        case type = "actionType"
        case dealId = "affectedDealId"
    }
}
