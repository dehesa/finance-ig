import ReactiveSwift
import Foundation

extension Streamer.Request.Deals {
    
    // MARK: TRADE:ACCID
    
    /// Subscribes to the given account and receives updates on positions, working orders, and trade confirmations.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter accountIdentifier: The Account identifier.
    /// - parameter fields: The account properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(to accountIdentifier: String, updates fields: Set<Streamer.Deal.Field>, snapshot: Bool = true) -> SignalProducer<Streamer.Deal,Streamer.Error> {
        let item = "TRADE:".appending(accountIdentifier)
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(mode: .distinct, item: item, fields: properties, snapshot: snapshot)
            .attemptMap { (update) in
                do {
                    return .success(try .init(identifier: accountIdentifier, item: item, update: update))
                } catch let error as Streamer.Error {
                    return .failure(error)
                } catch let error {
                    let representation = update.map { "\($0): \($1.value ?? "nil")" }.joined(separator: ", ")
                    return .failure(.invalidResponse(item: item, fields: update, message: "An unkwnon error occur will parsing a market chart update.\n\tPayload\(representation)\n\tError: \(error)"))
                }
        }
    }
}

// MARK: - Supporting Entities

extension Streamer.Request {
    /// Contains all functionality related to Streamer accounts.
    public struct Deals {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        fileprivate unowned let streamer: Streamer
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: Streamer) {
            self.streamer = streamer
        }
    }
}

// MARK: Request Entities

extension Streamer.Deal {
    /// Possible fields to subscribe to when querying account data.
    public enum Field: String, CaseIterable {
        /// Trade confirmations for an account.
        case confirmations = "CONFIRMS"
        /// Open position updates for an account.
        case positions = "OPU"
        /// Working order updates for an account.
        case workingOrders = "WOU"
    }
}

extension Set where Element == Streamer.Deal.Field {
    /// Returns all queryable fields.
    public static var all: Self {
        return .init(Element.allCases)
    }
}

// MARK: Respose Entities

extension Streamer {
    ///
    public struct Deal {
        /// Account identifier.
        let accountIdentifier: String
        /// Confirmation update.
        let confirmation: API.Confirmation?
        /// Open position update.
        let position: Self.Position?
        /// Working order update.
        /// - note: This seems never to be set up.
        let workingOrder: String?
        
        internal init(identifier: String, item: String, update: [String:Streamer.Subscription.Update]) throws {
            typealias F = Self.Field
            typealias U = Streamer.Formatter.Update
            
            let decoder = JSONDecoder()
            self.workingOrder = update[F.workingOrders.rawValue]?.value
            
            self.accountIdentifier = identifier
            do {
                self.confirmation = try update[F.confirmations.rawValue]?.value.map { try decoder.decode(API.Confirmation.self, from: .init($0.utf8)) }
                self.position = try update[F.positions.rawValue]?.value.map { try decoder.decode(Self.Position.self, from: .init($0.utf8)) }
            } catch let error as Streamer.Formatter.Update.Error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An error was encountered when parsing the value \"\(error.value)\" from a \"String\" to a \"\(error.type)\".")
            } catch let error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An unknown error was encountered when parsing the updated payload.\nError: \(error)")
            }
        }
    }
}

extension Streamer.Deal {
    /// Information relative to the position
    struct Position: Decodable {
        /// Permanent deal reference for a confirmed trade.
        public let identifier: API.Deal.Identifier
        /// Transient deal reference for an unconfirmed trade.
        public let reference: API.Deal.Reference
        /// Date the position was created.
        public let date: Date
        /// Instrument epic identifier.
        public let epic: Epic
        /// Instrument expiration period.
        public let expiry: API.Instrument.Expiry
        /// The position's currency.
        public let currency: Currency.Code
        /// Indicates whether the operation has been successfully performed or whether there was a problem and the operation hasn't been performed.
        public let isDealAccepted: Bool
        
        /// Position status.
        public let status: Self.Status
        /// Deal direction.
        public let direction: API.Deal.Direction
        /// The deal size
        public let size: Decimal
        /// Instrument price.
        public let level: Decimal
//        /// The level (i.e. instrument's price) at which the user is happy to "take profit".
//        public let limit: API.Deal.Limit?
//        /// The level at which the user doesn't want to incur more losses.
//        public let stop: API.Deal.Stop?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.identifier = try container.decode(API.Deal.Identifier.self, forKey: .identifier)
            self.reference = try container.decode(API.Deal.Reference.self, forKey: .reference)
            self.date = try container.decode(Date.self, forKey: .date, with: Streamer.Formatter.iso8601miliseconds)
            self.epic = try container.decode(Epic.self, forKey: .epic)
            self.expiry = try container.decode(API.Instrument.Expiry.self, forKey: .expiry)
            self.currency = try container.decode(Currency.Code.self, forKey: .currency)
            let dealStatus = try container.decode(String.self, forKey: .dealStatus)
            switch dealStatus {
            case "ACCEPTED": self.isDealAccepted = true
            case "REJECTED": self.isDealAccepted = false
            default: throw DecodingError.dataCorruptedError(forKey: .dealStatus, in: container, debugDescription: "The deal status value \"\(dealStatus)\" was not recognized.")
            }
            
            self.status = try container.decode(Self.Status.self, forKey: .positionStatus)
            self.direction = try container.decode(API.Deal.Direction.self, forKey: .direction)
            self.size = try container.decode(Decimal.self, forKey: .size)
            self.level = try container.decode(Decimal.self, forKey: .level)
            #warning("Figure out limits and stops.")
//            // Figure out limit.
//            let limitLevel = try container.decodeIfPresent(Decimal.self, forKey: .limitLevel)
//            let limitDistance = try container.decodeIfPresent(Decimal.self, forKey: .limitDistance)
//            switch (limitLevel, limitDistance) {
//            case (.none, .none):      self.limit = nil
//            case (.none, let dista?): self.limit = .distance(dista)
//            case (let level?, .none): self.limit = .position(level: level)
//            case (.some, .some): throw DecodingError.dataCorruptedError(forKey: .limitLevel, in: container, debugDescription: "Limit level and distance are both set on a deal confirmation. This is not suppose to happen!")
//            }
//            // Figure out stop.
//            let stop: API.Deal.Stop.Kind?
//            let stopLevel = try container.decodeIfPresent(Decimal.self, forKey: .stopLevel)
//            let stopDistance = try container.decodeIfPresent(Decimal.self, forKey: .stopDistance)
//            switch (stopLevel, stopDistance) {
//            case (.none, .none):      stop = nil
//            case (.none, let dista?): stop = .distance(dista)
//            case (let level?, .none): stop = .position(level: level)
//            case (.some, .some): throw DecodingError.dataCorruptedError(forKey: .stopLevel, in: container, debugDescription: "Stop level and distance are both set on a deal confirmation. This is not suppose to happen!")
//            }
//            if let stop = stop {
//                let isGuaranteed = try container.decode(Bool.self, forKey: .isStopGuaranteed)
//                let isTrailing = try container.decode(Bool.self, forKey: .isStopTrailing)
//                let risk: API.Deal.Stop.Risk = (isGuaranteed) ? .limited(premium: nil) : .exposed
//                let trailing: API.Deal.Stop.Trailing = (isTrailing) ? .dynamic(nil) : .static
//                self.stop = .init(stop, risk: risk, trailing: trailing)
//            } else {
//                self.stop = nil
//            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case identifier = "dealId"
            case reference = "dealReference"
            case date = "timestamp"
            case epic, expiry, currency
            case dealStatus, positionStatus = "status"
            case direction, size, level
//
//            case limitLevel, limitDistance
//            case stopLevel, stopDistance
//            case isStopGuaranteed = "guaranteedStop"
//            case isStopTrailing = "trailingStop"
        }
    }
}

extension Streamer.Deal.Position {
    /// Position status.
    public enum Status: Decodable {
        case open
        case updated
        case deleted
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            switch value {
            case Self.CodingKeys.open.rawValue: self = .open
            case Self.CodingKeys.updated.rawValue: self = .updated
            case Self.CodingKeys.deleted.rawValue: self = .deleted
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "The status value \"\(value)\" couldn't be parsed.")
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case open = "OPEN"
            case updated = "UPDATED"
            case deleted = "DELETED"
        }
    }
}

extension Streamer.Deal: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result: String = self.accountIdentifier
        result.append(prefix: "\n\t", name: "Confirmation", ": ", self.confirmation)
        result.append(prefix: "\n\n\t", name: "Position", ": ", self.position)
        result.append(prefix: "\n\n\t", name: "Working Order", ": ", self.workingOrder)
        return result
    }
}
