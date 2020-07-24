import Foundation
import Decimals

extension Streamer {
    /// Open position data.
    public struct Update {
        /// The date at which the update has been generated/received.
        /// - attention: This is NOT the position creation date.
        public let date: Date
        /// Values related to deal representing the open position (and its origin if any).
        public let deal: Self.Deal
        /// The actual trade (whether a position or a working order).
        public let trade: Self.Trade
    }
}

extension Streamer.Update {
    /// Overarching deal representing an open position.
    public struct Deal: Identifiable {
        /// Permanent deal reference for a confirmed trade.
        public let id: IG.Deal.Identifier
        /// Transient deal reference for an unconfirmed trade.
        public let reference: IG.Deal.Reference
        /// The deal status.
        public let status: Self.Status
        /// Deal identifier of the originating deal.
        public let originId: IG.Deal.Identifier?
    }
}

extension Streamer.Update.Deal {
    /// The deal status.
    public enum Status: Equatable {
        case accepted
        case rejected(reason: String? = nil)
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.accepted, .accepted), (.rejected, .rejected): return true
            default: return false
            }
        }
    }
}

extension Streamer.Update {
    /// The details of the given trade.
    public struct Trade {
        /// The position status.
        public let status: Self.Status
        /// The type of trade being updated.
        public let type: Self.Kind
        /// Instrument epic identifier.
        public let epic: IG.Market.Epic
        /// Instrument expiry period.
        public let expiry: IG.Market.Expiry
        /// Deal direction.
        public let direction: IG.Deal.Direction
        /// Deal size.
        public let size: Decimal64
        /// Level (instrument price) at which the position was openend.
        public let level: Decimal64
        /// User channel.
        public let channel: String
    }
}

extension Streamer.Update.Trade {
    /// The position status.
    public enum Status: Hashable {
        case open
        case updated
        case deleted
    }
    
    /// The trade type.
    public enum Kind {
        case position(Streamer.Update.Trade.Position)
        case workingOrder(Streamer.Update.Trade.WorkingOrder)
    }
}

extension Streamer.Update.Trade {
    /// Open position.
    public struct Position {
        /// The level (i.e. instrument's price) at which the user is happy to "take profit".
        public let limitLevel: Decimal64?
        /// The level (i.e. instrument's price) at which the user doesn't want to incur more losses.
        public let stop: (level: Decimal64, risk: IG.Deal.Stop.Risk)?
    }
}


extension Streamer.Update.Trade {
    /// Working order waiting for the triggers to be hit.
    public struct WorkingOrder {
        /// The working order type.
        public let type: IG.Deal.WorkingOrder
        /// Indicates when the working order expires if its triggers hasn't been met.
        public let expiration: IG.Deal.WorkingOrder.Expiration
        /// Position currency ISO code.
        public let currency: Currency.Code?
        /// The level (i.e. instrument's price) at which the user is happy to "take profit".
        public let limitDistance: Decimal64?
        /// The level (i.e. instrument's price) at which the user doesn't want to incur more losses.
        public let stop: (distance: Decimal64, risk: IG.Deal.Stop.Risk)?
    }
}

// MARK: -

extension Streamer.Update: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.date = try container.decode(Date.self, forKey: .date, with: .iso8601)
        self.deal = try .init(from: decoder)
        self.trade = try .init(from: decoder)
    }
    
    private enum _Keys: String, CodingKey {
        case date = "timestamp"
    }
}

extension Streamer.Update.Deal: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.id = try container.decode(IG.Deal.Identifier.self, forKey: .dealId)
        self.reference = try container.decode(IG.Deal.Reference.self, forKey: .dealReference)
        self.originId = try container.decodeIfPresent(IG.Deal.Identifier.self, forKey: .dealIdOrigin)
        switch try container.decode(String.self, forKey: .dealStatus) {
        case "ACCEPTED": self.status = .accepted
        case "REJECTED": self.status = .rejected(reason: try container.decodeIfPresent(String.self, forKey: .reason))
        case let value: throw DecodingError.dataCorruptedError(forKey: .dealStatus, in: container, debugDescription: "Invalid deal status '\(value)'.")
        }
    }
    
    private enum _Keys: String, CodingKey {
        case dealId, dealReference, dealStatus, reason, dealIdOrigin
    }
}

extension Streamer.Update.Trade: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        
        switch try container.decode(String.self, forKey: .status) {
        case "OPEN": self.status = .open
        case "UPDATED": self.status = .updated
        case "DELETED": self.status = .deleted
        case let value: throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "Invalid OPU status '\(value)'.")
        }
        
        self.type = try .init(from: decoder)
        self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
        self.expiry = try container.decode(IG.Market.Expiry.self, forKey: .expiry)
        self.direction = try container.decode(IG.Deal.Direction.self, forKey: .direction)
        self.size = try container.decode(Decimal64.self, forKey: .size)
        self.level = try container.decode(Decimal64.self, forKey: .level)
        self.channel = try container.decode(String.self, forKey: .channel)
    }
    
    private enum _Keys: String, CodingKey {
        case status, epic, expiry
        case direction, size, level, channel
    }
}

extension Streamer.Update.Trade.Kind: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        if let orderType = try container.decodeIfPresent(IG.Deal.WorkingOrder.self, forKey: .type) {
            let expiration: IG.Deal.WorkingOrder.Expiration
            switch try container.decode(String.self, forKey: .expiration) {
            case "GOOD_TILL_CANCELLED": expiration = .tillCancelled
            case "GOOD_TILL_DATE": expiration = .tillDate(try container.decode(Date.self, forKey: .expirationDate, with: DateFormatter.iso8601NoSeconds))
            case let value: throw DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: "Invalid working order expiration '\(value)'.")
            }
            
            let currency = try container.decodeIfPresent(IG.Currency.Code.self, forKey: .currency)
            let limitDistance = try container.decodeIfPresent(Decimal64.self, forKey: .limitDistance)
            
            let stop: (Decimal64, IG.Deal.Stop.Risk)?
            if let stopLevel = try container.decodeIfPresent(Decimal64.self, forKey: .stopDistance) {
                let risk: IG.Deal.Stop.Risk = (try container.decode(Bool.self, forKey: .isStopGuaranteed)) ? .limited : .exposed
                stop = (stopLevel, risk)
            } else { stop = nil }
            
            let workingOrder = Streamer.Update.Trade.WorkingOrder(type: orderType, expiration: expiration, currency: currency, limitDistance: limitDistance, stop: stop)
            self = .workingOrder(workingOrder)
        } else {
            let limitLevel = try container.decodeIfPresent(Decimal64.self, forKey: .limitLevel)
            
            let stop: (Decimal64, IG.Deal.Stop.Risk)?
            if let stopLevel = try container.decodeIfPresent(Decimal64.self, forKey: .stopLevel) {
                let risk: IG.Deal.Stop.Risk = (try container.decode(Bool.self, forKey: .isStopGuaranteed)) ? .limited : .exposed
                stop = (stopLevel, risk)
            } else { stop = nil }
            
            self = .position(.init(limitLevel: limitLevel, stop: stop))
        }
    }
    
    private enum _Keys: String, CodingKey {
        case type = "orderType", expiration = "timeInForce", expirationDate = "goodTillDateISO", currency
        case limitLevel, limitDistance
        case stopLevel, stopDistance, isStopGuaranteed = "guaranteedStop"
    }
}
