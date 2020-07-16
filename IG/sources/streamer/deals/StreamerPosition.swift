import Combine
import Foundation
import Decimals

extension Streamer.Request.Deals {
    
    // MARK: TRADE:ACCID

    /// Subscribes to the given account and receives updates on open positions.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter account: The Account identifier.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - returns: Signal producer that can be started at any time.
    public func subscribeToPositions(account: IG.Account.Identifier, snapshot: Bool = true) -> AnyPublisher<Streamer.Position,Streamer.Error> {
        let (item, field) = ("TRADE:".appending(account.rawValue), Streamer.Deal.Field.positions.rawValue)
        let decoder = JSONDecoder()
        
        return self.streamer.channel
            .subscribe(on: self.streamer.queue, mode: .distinct, item: item, fields: [field], snapshot: snapshot)
            .tryCompactMap { (update) -> Streamer.Position? in
                guard let payload = update[field]?.value else { return nil }
                do {
                    return try decoder.decode(Streamer.Position.self, from: .init(payload.utf8))
                } catch var error as Streamer.Error {
                    if case .none = error.item { error.item = item }
                    if case .none = error.fields { error.fields = [field] }
                    throw error
                } catch let underlyingError {
                    throw Streamer.Error.invalidResponse(.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: .reviewError)
                }
            }.mapError(Streamer.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension Streamer {
    /// Open position data.
    public struct Position: Decodable {
        /// The date at which the update has been generated/received.
        /// - attention: This is NOT the position creation date.
        public let date: Date
        
        /// Values related to deal representing the open position (and its origin if any).
        public let deal: Self.Deal
        /// The market's instrument.
        public let instrument: Self.Instrument
        /// The position details (such as its status, size, limit, stop, etc.)
        public let details: Self.Details?
    }
}

extension Streamer.Position {
    /// Overarching deal representing an open position.
    public struct Deal: Decodable {
        /// Permanent deal reference for a confirmed trade.
        public let identifier: IG.Deal.Identifier
        /// Transient deal reference for an unconfirmed trade.
        public let reference: IG.Deal.Reference
        /// Deal identifier of the originating deal.
        public let identifierOrigin: IG.Deal.Identifier?
        /// The deal status.
        public let status: Self.Status
        /// User channel.
        public let channel: String?
        
        /// The deal status.
        public enum Status {
            case accepted
            case rejected(reason: String? = nil)
        }
    }
    
    /// Market's instrument properties.
    public struct Instrument: Decodable {
        /// Instrument epic identifier.
        public let epic: Market.Epic
        /// Instrument expiry period.
        public let expiry: Market.Expiry
        /// Position currency ISO code.
        public let currency: Currency.Code?
    }
    
    /// If the `deal.status` is `.accepted`, this structure will provide further information about an open position.
    public struct Details: Decodable {
        /// The position status.
        public let status: Streamer.Position.Status
        /// Deal direction.
        public let direction: IG.Deal.Direction
        /// Deal size.
        public let size: Decimal64
        /// Level (instrument price) at which the position was openend.
        public let level: Decimal64
        /// The level (i.e. instrument's price) at which the user is happy to "take profit".
        public let limit: IG.Deal.Limit?
        /// The level (i.e. instrument's price) at which the user doesn't want to incur more losses.
        public let stop: IG.Deal.Stop?
    }
    
    /// The position status.
    public enum Status: String, Decodable {
        case open = "OPEN"
        case updated = "UPDATED"
        case deleted = "DELETED"
    }
}

// MARK: -

extension Streamer.Position.Details {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.status = try container.decode(Streamer.Position.Status.self, forKey: .status)
        self.direction = try container.decode(IG.Deal.Direction.self, forKey: .direction)
        self.size = try container.decode(Decimal64.self, forKey: .size)
        self.level = try container.decode(Decimal64.self, forKey: .level)
        self.limit = try container.decodeIfPresent(IG.Deal.Limit.self, forLevelKey: .limitLevel, distanceKey: .limitDistance)
        self.stop = try container.decodeIfPresent(IG.Deal.Stop.self, forLevelKey: .stopLevel, distanceKey: .stopDistance, riskKey: (.isStopGuaranteed, .stopRiskPremium), trailingKey: (.isStopTrailing, .stopTrailingDistance, .stopTrailingIncrement))
    }
    
    private enum _Keys: String, CodingKey {
        case status, direction, size, level, limitLevel, limitDistance, stopLevel, stopDistance
        case isStopGuaranteed = "guaranteedStop", stopRiskPremium = "limitedRiskPremium"
        case isStopTrailing = "trailingStop", stopTrailingDistance = "trailingStopDistance", stopTrailingIncrement = "trailingStep"
    }
}

extension Streamer.Position {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.date = try container.decode(Date.self, forKey: .date, with: .iso8601)
        self.deal = try .init(from: decoder)
        self.instrument = try .init(from: decoder)
        if case .accepted = self.deal.status {
            self.details = try Self.Details(from: decoder)
        } else {
            self.details = .none
        }
    }
    
    private enum _Keys: String, CodingKey {
        case date = "timestamp"
    }
}

extension Streamer.Position.Deal {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.identifier = try container.decode(IG.Deal.Identifier.self, forKey: .dealId)
        self.reference = try container.decode(IG.Deal.Reference.self, forKey: .dealReference)
        self.identifierOrigin = try container.decodeIfPresent(IG.Deal.Identifier.self, forKey: .dealIdOrigin)
        switch try container.decode(String.self, forKey: .dealStatus) {
        case "ACCEPTED": self.status = .accepted
        case "REJECTED": self.status = .rejected(reason: try container.decodeIfPresent(String.self, forKey: .reason))
        default: throw DecodingError.dataCorruptedError(forKey: .dealStatus, in: container, debugDescription: "The deal status value couldn't be matched to a supported value.")
        }
        self.channel = try container.decodeIfPresent(String.self, forKey: .channel)
    }
    
    private enum _Keys: String, CodingKey {
        case dealId, dealReference, dealIdOrigin, dealStatus, reason, channel
    }
}
