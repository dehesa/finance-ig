import ReactiveSwift
import Foundation

extension API.Request.Positions {
    
    // MARK: - GET /confirms/{dealReference}
    
    /// It is used to received a confirmation on a deal (whether position or working order)
    ///
    /// Trade confirmation is done in two phases:
    /// - **Acknowledgement**. A deal reference is returned via the `createPosition()` or `createWorkingOrder()` endpoints when an order is placed.
    /// - **Confirmation**. A deal identifier is received by subscribing to the `TRADES:CONFIRMS` streaming messages (recommended), or by polling this endpoint (`confirmTransientPositions`).
    /// Most orders are usually executed within a few milliseconds but the confirmation may not be available immediately if there is a delay. Also not the confirmation is only available up to 1 minute via this endpoint.
    /// - parameter reference: Temporary targeted deal reference.
    public func confirm(reference: API.Position.Reference) -> SignalProducer<API.Position.Confirmation,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "confirms/\(reference.rawValue)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }
}

// MARK: - Supporting Entities

// MARK: Response Entities

extension API.Position {
    /// Confirmation data returned just after opening a position or a working order.
    public struct Confirmation: Decodable {
        /// Permanent deal reference for a confirmed trade.
        public let identifier: API.Position.Identifier
        /// Transient deal reference for an unconfirmed trade.
        public let reference: API.Position.Reference
        /// Date the position was created.
        public let date: Date
        /// Instrument epic identifier.
        public let epic: Epic
        /// Instrument expiration period.
        public let expiry: API.Expiry
        /// Indicates whether the operation has been successfully performed or whether there was a problem and the operation hasn't been performed.
        public let status: Self.Status
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.identifier = try container.decode(API.Position.Identifier.self, forKey: .identifier)
            self.reference = try container.decode(API.Position.Reference.self, forKey: .reference)
            self.date = try container.decode(Date.self, forKey: .date, with: API.DateFormatter.iso8601Miliseconds)
            
            self.epic = try container.decode(Epic.self, forKey: .epic)
            self.expiry = try container.decode(API.Expiry.self, forKey: .expiry)
            
            let status = try container.decode(Self.CodingKeys.StatusKeys.self, forKey: .status)
            guard case .accepted = status else {
                let reason = try container.decode(Self.RejectionReason.self, forKey: .reason)
                self.status = .rejected(reason: reason)
                return
            }
            
            let details = try Self.Details(from: decoder)
            self.status = .accepted(details: details)
        }
        
        public var isAccepted: Bool {
            switch self.status {
            case .accepted(_): return true
            case .rejected(_): return false
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case identifier = "dealId"
            case reference = "dealReference"
            case date, epic, expiry
            case status = "dealStatus"
            case reason
            
            enum StatusKeys: String, Decodable {
                case accepted = "ACCEPTED"
                case rejected = "REJECTED"
            }
        }
        
        /// The operation confirmation status.
        public enum Status {
            /// The operation has been confirmed successfully.
            case accepted(details: API.Position.Confirmation.Details)
            /// The operation has been rejected due to the reason given as an associated value.
            case rejected(reason: API.Position.Confirmation.RejectionReason)
        }
    }
}

extension API.Position.Confirmation {
    public struct Details: Decodable {
        /// Position status.
        public let status: API.Position.Status
        /// Affected deals.
        public let affectedDeals: [API.Position.Confirmation.Deal]
        /// Deal direction.
        public let direction: API.Position.Direction
        /// The deal size
        public let size: Double
        /// Instrument price.
        public let level: Double
        /// The level (i.e. instrument's price) at which the user is happy to "take profit".
        public let limit: Double?
        /// The level at which the user doesn't want to incur more losses.
        public let stop: API.Position.Stop?
        /// Profit (value and currency).
        public let profit: API.Position.Confirmation.Profit?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.status = try container.decode(API.Position.Status.self, forKey: .status)
            self.affectedDeals = try container.decode([API.Position.Confirmation.Deal].self, forKey: .affectedDeals)
            
            self.direction = try container.decode(API.Position.Direction.self, forKey: .direction)
            self.size = try container.decode(Double.self, forKey: .size)
            self.level = try container.decode(Double.self, forKey: .level)
            
            self.limit = try container.decodeIfPresent(Double.self, forKey: .limitLevel)
            if let limitDistance = try container.decodeIfPresent(Double.self, forKey: .limitDistance) {
                throw DecodingError.dataCorruptedError(forKey: .limitDistance, in: container, debugDescription: "In testing \"\(Self.CodingKeys.limitDistance.rawValue)\" has never been set. Here, however, seems to have a value of \"\(limitDistance)\". Please report this deal/confirmation to the maintainer.")
            }
            
            if let stopLevel = try container.decodeIfPresent(Double.self, forKey: .stopLevel) {
                let isGuaranteed = try container.decode(Bool.self, forKey: .guaranteedStop)
                let isTrailing = try container.decode(Bool.self, forKey: .trailingStop)
                switch (isGuaranteed, isTrailing) {
                case (let isGuaranteed, false):
                    let risk: API.Position.Stop.Risk = (isGuaranteed) ? .limited(premium: nil) : .exposed
                    self.stop = .position(level: stopLevel, risk: risk)
                case (false, true):
                    self.stop = .trailing(level: stopLevel, tail: nil)
                case (true, true):
                    throw DecodingError.dataCorruptedError(forKey: .trailingStop, in: container, debugDescription: "A guaranteed stop cannot be a trailing stop.")
                }
            } else {
                self.stop = nil
            }
            
            if let stopDistance = try container.decodeIfPresent(Double.self, forKey: .stopDistance) {
                throw DecodingError.dataCorruptedError(forKey: .stopDistance, in: container, debugDescription: "In testing \"\(Self.CodingKeys.stopDistance.rawValue)\" has never been set. Here, however, seems to have a value of \"\(stopDistance)\". Please report this deal/confirmation to the maintainer.")
            }
            
            let profitValue = try container.decodeIfPresent(Double.self, forKey: .profitValue)
            let profitCurrency = try container.decodeIfPresent(Currency.self, forKey: .profitCurrency)
            switch (profitValue, profitCurrency) {
            case (let value?, let currency?):
                self.profit = .init(value: value, currency: currency)
            case (.none, .none):
                self.profit = nil
            default:
                let description = "Both \"\(Self.CodingKeys.profitValue.rawValue)\" and \"\(Self.CodingKeys.profitCurrency.rawValue)\" must be set or be `nil` at the same time."
                throw DecodingError.dataCorruptedError(forKey: .profitValue, in: container, debugDescription: description)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case status, affectedDeals
            case direction, size, level
            case limitLevel, limitDistance
            case stopLevel, stopDistance, guaranteedStop, trailingStop
            case profitValue = "profit"
            case profitCurrency = "profitCurrency"
        }
    }
    
    /// A brief representation of a deal/position.
    public struct Deal: Decodable {
        /// Deal identifier.
        public let identifier: String
        /// Deal current status.
        public let status: API.Position.Status
        
        private enum CodingKeys: String, CodingKey {
            case identifier = "dealId"
            case status
        }
    }
    
    /// Profit value and currency.
    public struct Profit: CustomStringConvertible {
        /// The actual profit value (it can be negative).
        public let value: Double
        /// The profit currency.
        public let currency: Currency
        
        fileprivate init(value: Double, currency: Currency) {
            self.value = value
            self.currency = currency
        }
        
        public var description: String {
            return "\(self.currency)\(self.value)"
        }
    }

    /// Description of trading operation error.
    public enum RejectionReason: String, Decodable {
        /// The operation resulted in an unknown result condition. Check transaction history or contact support for further information.
        case unknown = "UNKNOWN"
        /// An error has occurred but no detailed information is available. Check transaction history or contact support for further information.
        case generalError = "GENERAL_ERROR"
        
        /// The deal has been rejected because of an existing position. Either set the 'force open' to be true or cancel opposing position.
        case alreadyExistingPosition = "POSITION_ALREADY_EXISTS_IN_OPPOSITE_DIRECTION"
        /// The epic is due to expire shortly, client should deal in the next available contract.
        case closingMarket = "MARKET_CLOSING"
        /// The market is currently closed.
        case closedMarket = "MARKET_CLOSED"
        /// The market is currently closed with edits.
        case closedMarketEdits = "MARKET_CLOSED_WITH_EDITS"
        /// Resubmitted request does not match the original order.
        case conflictingOrder = "CONFLICTING_ORDER"
        /// The account is not enabled to trade
        case disabledAccount = "ACCOUNT_NOT_ENABLED_TO_TRADING"
        /// The order has been rejected as it is a duplicate of a previously issued order.
        case duplicatedOrder = "DUPLICATE_ORDER_ERROR"
        /// Exchange check failed. Please call in for assistance.
        case failedExchanged = "EXCHANGE_MANUAL_OVERRIDE"
        /// Cannot close this position. Either the position no longer exists, or the size available to close is less than the size specified.
        case failedPositionClose = "POSITION_NOT_AVAILABLE_TO_CLOSE"
        /// Invalid attempt to submit a spreadbet trade on a CFD account.
        case failedSpreadbetOpen = "REJECT_SPREADBET_ORDER_ON_CFD_ACCOUNT"
        /// The requested market was not found.
        case instrumentNotFound = "INSTRUMENT_NOT_FOUND"
        /// The account has not enough funds available for the requested trade.
        case insufficientFunds = "INSUFFICIENT_FUNDS"
        /// The requested operation has been attempted on the wrong direction.
        case invalidDirection = "WRONG_SIDE_OF_MARKET"
        /// Order expiry is less than the sprint market's minimum expiry. Check the sprint market's market details for the allowable expiries.
        case invalidExpirationDateMinimum = "EXPIRY_LESS_THAN_SPRINT_MARKET_MIN_EXPIRY"
        /// The expiry of the position would have fallen after the closing time of the market.
        case invalidExpirationDatePlace = "SPRINT_MARKET_EXPIRY_AFTER_MARKET_CLOSE"
        /// The working order has been set to expire on a past date.
        case invalidGoodTillDate = "GOOD_TILL_DATE_IN_THE_PAST"
        /// Instrument has an error.
        ///
        /// Check the order's currency is the instrument's currency (see the market's details); otherwise please contact support.
        case invalidInstrument = "CONTACT_SUPPORT_INSTRUMENT_ERROR"
        /// The limit level you have requested is closer to the market level than the existing stop. When the market is closed you can only move the limit order further away from the current market level.
        case invalidLevelLimitAway = "MOVE_AWAY_ONLY_LIMIT"
        /// The deal has been rejected because the limit level is inconsistent with current market price given the direction.
        case invalidLevelLimitWrongSide = "LIMIT_ORDER_WRONG_SIDE_OF_MARKET"
        /// The stop level you have requested is closer to the market level than the existing stop level. When the market is closed you can only move the stop level further away from the current market level.
        case invalidLevelStopAway = "MOVE_AWAY_ONLY_STOP"
        /// The market level has moved and has been rejected
        case invalidMarketLevel = "LEVEL_TOLERANCE_ERROR"
        /// Order declined during margin checks Check available funds.
        case invalidMargin = "MARGIN_ERROR"
        /// The order level you have requested is moving closer to the market level than the exisiting order level. When the market is closed you can only move the order further away from the current market level.
        case invalidOrderLevelAway = "MOVE_AWAY_ONLY_TRIGGER_LEVEL"
        /// The level of the attached stop or limit is not valid.
        case invalidOrderLevel = "ATTACHED_ORDER_LEVEL_ERROR"
        /// Invalid attempt to submit a CFD trade on a spreadbet account.
        case invalidOrderCFD = "REJECT_CFD_ORDER_ON_SPREADBET_ACCOUNT"
        /// Opening CR position in opposite direction to existing CR position not allowed.
        case invalidPositionCR = "OPPOSING_DIRECTION_ORDERS_NOT_ALLOWED"
        /// The order size exceeds the instrument's maximum configured value for auto-hedging the exposure of a deal.
        case invalidSizeMax = "MAX_AUTO_SIZE_EXCEEDED"
        /// The order size is too small.
        case invalidSizeMin = "MINIMUM_ORDER_SIZE_ERROR"
        /// Sorry we are unable to process this order. The stop or limit level you have requested is not a valid trading level in the underlying market.
        case invalidSpace = "CR_SPACING"
        /// The submitted strike level is invalid.
        case invalidStrikeLevel = "STRIKE_LEVEL_TOLERANCE"
        /// The trailing stop value is invalid.
        case invalidTrailingStop = "ATTACHED_ORDER_TRAILING_STOP_ERROR"
        /// Cannot change the stop type.
        case immutableStopType = "CANNOT_CHANGE_STOP_TYPE"
        /// The manual order timeout limit has been reached.
        case manualOrderTimeout = "MANUAL_ORDER_TIMEOUT"
        /// The market is currently offline.
        case marketOffline = "MARKET_OFFLINE"
        /// The market has been rolled to the next period.
        case marketRolled = "MARKET_ROLLED"
        /// We are not taking opening deals on a Controlled Risk basis on this market.
        case openTradesUnavailable = "CLOSING_ONLY_TRADES_ACCEPTED_ON_THIS_MARKET"
        /// Order declined; please contact Support.
        case orderDeclined = "ORDER_DECLINED"
        /// The order is locked and cannot be edited by the user.
        case orderLocked = "ORDER_LOCKED"
        /// The order has not been found.
        case orderNotFound = "ORDER_NOT_FOUND"
        /// The total position size at this stop level is greater than the size allowed on this market. Please reduce the size of the order.
        case overflowSize = "OVER_NORMAL_MARKET_SIZE"
        /// The total size of deals placed on this market in a short period has exceeded our limits. Please wait before attempting to open further positions on this market.
        case platformLimitReached = "FINANCE_REPEAT_DEALING"
        /// The market can only be traded over the phone.
        case phoneOnlyMarket = "MARKET_PHONE_ONLY"
        /// The position has not been found.
        case positionNotFound = "POSITION_NOT_FOUND"
        /// Ability to force open in different currencies on same market not allowed.
        case prohibitedForceOpen = "FORCE_OPEN_ON_SAME_MARKET_DIFFERENT_CURRENCY"
        /// The requested market is not allowed to this account.
        case prohibitedMarket = "MARKET_UNAVAILABLE_TO_CLIENT"
        /// The epic does not support 'Market' order type.
        case prohibitedMarketOrders = "MARKET_ORDERS_NOT_ALLOWED_ON_INSTRUMENT"
        /// The deal has been rejected to avoid having long and short open positions on the same market or having long and short open positions and working orders on the same epic.
        case prohibitedOpposingPositions = "OPPOSING_POSITIONS_NOT_ALLOWED"
        /// The market does not allow opening shorting positions.
        case prohibitedShorting = "MARKET_NOT_BORROWABLE"
        /// The market does not allow stop or limit attached orders.
        case prohibitStopLimit = "STOP_OR_LIMIT_NOT_ALLOWED"
        /// The order requires a stop.
        case requiredStop = "STOP_REQUIRED_ERROR"
        /// The market or the account do not allow for trailing stops.
        case prohibitedTrailingStop = "TRAILING_STOP_NOT_ALLOWED"
        /// Order size is not an increment of the value specified for the market.
        case sizeIncrement = "SIZE_INCREMENT"
        /// Position cannot be cancelled. Check transaction history or contact support for further information.
        case uncancellablePosition = "POSITION_NOT_AVAILABLE_TO_CANCEL"
        /// Position cannot be deleted as it has been partially closed.
        case unremovablePartiallyClosedPosition = "PARTIALY_CLOSED_POSITION_NOT_DELETED"
        /// Cannot remove the stop.
        case unremovableStop = "CANNOT_REMOVE_STOP"
        
        // Included here for completion purposes. It is received on a confirmation that has been accepted.
        // private static let success = "SUCCESS"
    }
}
