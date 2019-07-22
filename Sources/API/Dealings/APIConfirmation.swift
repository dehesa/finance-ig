import ReactiveSwift
import Foundation

// MARK: - Supporting Entities

//extension API {
//    /// Used to received a confirmation on a deal (whether position or working order)
//    ///
//    /// Trade confirmation is done in two phases:
//    /// - **Acknowledgement**. A deal reference is returned via the `createPosition()` or `createWorkingOrder()` endpoints when an order is placed.
//    /// - **Confirmation**. A deal identifier is received by subscribing to the `TRADES:CONFIRMS` streaming messages (recommended), or by polling this endpoint (`confirmTransientPositions`).
//    /// Most orders are usually executed within a few milliseconds but the confirmation may not be available immediately if there is a delay. Also not the confirmation is only available up to 1 minute via this endpoint.
//    /// - parameter reference: Targeted deal reference.
//    public func confirmation(reference: String) -> SignalProducer<APIResponseConfirmation,API.Error> {
//        return SignalProducer(api: self) { (_) -> Void in
//                guard !reference.isEmpty else {
//                    throw API.Error.invalidRequest(underlyingError: nil, message: "Deal confirmation failed! The deal identifier cannot be empty.")
//                }
//            }.request(.get, "confirms/\(reference)", version: 1, credentials: true)
//            .send(expecting: .json)
//            .validateLadenData(statusCodes: 200)
//            .attemptMap { (request, header, data) -> Result<APIResponseConfirmation,API.Error> in
//                let decoder = JSONDecoder()
//                let result: APIResponseConfirmation
//                do {
//                    let confirmation = try decoder.decode(API.Response.Confirmation.self, from: data)
//                    result = (confirmation.isAccepted) ? try decoder.decode(API.Response.Confirmation.Accepted.self, from: data)
//                        : try decoder.decode(API.Response.Confirmation.Rejected.self, from: data)
//                } catch let e {
//                    let error: API.Error = .invalidResponse(header, request: request, data: data, underlyingError: e, message: "The response body could not be parsed to the expected type: \"\(APIResponseConfirmation.self)\".")
//                    return .failure(error)
//                }
//                return .success(result)
//        }
//    }
//}
//
//// MARK: -
//
///// Trade confirmation of a given deal.
//public protocol APIResponseConfirmation {
//    /// Permanent deal reference for a confirmed trade.
//    var identifier: String { get }
//    /// Transient deal reference for an unconfirmed trade.
//    var reference: String { get }
//    /// Transaction date.
//    var date: Date { get }
//    /// Deal status.
//    var isAccepted: Bool { get }
//}
//
//extension APIResponseConfirmation {
//    /// Transforms the current structure into an accepted response if `isAccepted` is `true`.
//    var acceptedResponse: API.Response.Confirmation.Accepted? {
//        guard isAccepted else { return nil }
//        return self as? API.Response.Confirmation.Accepted
//    }
//    
//    /// Transforms the current structure into a rejected response if `isAccepted` is `false`.
//    var rejectedResponse: API.Response.Confirmation.Rejected? {
//        guard !isAccepted else { return nil }
//        return self as? API.Response.Confirmation.Rejected
//    }
//}
//
//// MARK: -
//
//extension API.Response {
//    /// Confirmation related types.
//    public struct Confirmation: APIResponseConfirmation, Decodable {
//        public let identifier: String
//        public let reference: String
//        public let date: Date
//        public let isAccepted: Bool
//        
//        public init(from decoder: Decoder) throws {
//            let container = try decoder.container(keyedBy: CodingKeys.self)
//            self.identifier = try container.decode(String.self, forKey: .identifier)
//            self.reference = try container.decode(String.self, forKey: .reference)
//            self.date = try container.decode(Date.self, forKey: .date, with: API.DateFormatter.iso8601Miliseconds)
//            let status = try container.decode(Status.self, forKey: .status)
//            self.isAccepted = status == .accepted
//        }
//        
//        private enum Status: String, Decodable {
//            case accepted = "ACCEPTED"
//            case rejected = "REJECTED"
//        }
//        
//        private enum CodingKeys: String, CodingKey {
//            case identifier = "dealId"
//            case reference = "dealReference"
//            case date
//            case status = "dealStatus"
//        }
//    }
//}
//
//extension API.Response.Confirmation {
//    /// Accepted position confirmation.
//    public struct Accepted: APIResponseConfirmation, Decodable {
//        public let identifier: String
//        public let reference: String
//        public let date: Date
//        public let isAccepted: Bool
//        /// Position status.
//        public let status: API.Position.Status
//        /// Affected deals.
//        public let affectedDeals: [Deal]
//        /// Instrument epic identifier.
//        public let epic: String
//        /// Size.
//        public let size: Double
//        /// Deal direction.
//        public let direction: API.Position.Direction
//        /// Instrument price.
//        public let level: Double
//        /// The limit and stop boundaries at which the user is happy reaping the benefits, or doesn't want to incur more losses.
//        public let boundaries: Boundaries
//        /// Instrument expiration period.
//        public let expiry: API.Expiry
//        /// Profit (value and currency).
//        public let profit: Profit?
//        
//        public init(from decoder: Decoder) throws {
//            let confirmation = try API.Response.Confirmation(from: decoder)
//            self.identifier = confirmation.identifier
//            self.reference = confirmation.reference
//            self.date = confirmation.date
//            self.isAccepted = confirmation.isAccepted
//            
//            let container = try decoder.container(keyedBy: CodingKeys.self)
//            self.status = try container.decode(API.Position.Status.self, forKey: .status)
//            self.affectedDeals = try container.decode([Deal].self, forKey: .affectedDeals)
//            self.epic = try container.decode(String.self, forKey: .epic)
//            self.size = try container.decode(Double.self, forKey: .size)
//            self.direction = try container.decode(API.Position.Direction.self, forKey: .direction)
//            self.level = try container.decode(Double.self, forKey: .level)
//            self.boundaries = try Boundaries(from: decoder)
//            self.expiry = try container.decodeIfPresent(API.Expiry.self, forKey: .expiry) ?? .none
//            
//            if let value = try container.decodeIfPresent(Double.self, forKey: .profitValue),
//                let currency = try container.decodeIfPresent(String.self, forKey: .profitCurrency) {
//                self.profit = Profit(value: value, currency: currency)
//            } else {
//                self.profit = nil
//            }
//        }
//        
//        private enum CodingKeys: String, CodingKey {
//            case status
//            case affectedDeals
//            case epic
//            case size
//            case direction
//            case level
//            case profitValue = "profit"
//            case profitCurrency = "profitCurrency"
//            case expiry
//        }
//        
//        /// A brief representation of a deal/position.
//        public struct Deal: Decodable {
//            /// Deal identifier.
//            public let identifier: String
//            /// Deal current status.
//            public let status: API.Position.Status
//            
//            private enum CodingKeys: String, CodingKey {
//                case identifier = "dealId"
//                case status
//            }
//        }
//        
//        /// Reflect the boundaries for a deal level.
//        public struct Boundaries: APIPositionBoundaries, Decodable {
//            public let limit: API.Position.Boundary.Limit?
//            public let stop: API.Position.Boundary.Stop?
//            /// Whether the previously defined stop is trailing or not.
//            ///
//            /// Sadly, by the way the API is constructed, the `stop` property will never by `.trailing(_)`, instead, this boolean will indicate if the stop is trailing or not (although it won't give an indicating of the distance nor the increment).
//            public let isTrailingStop: Bool
//            /// Boolean indicating if a guaranteed stop is required.
//            ///
//            /// A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
//            /// - note: Guaranteed stops come at the price of an increased spread
//            public let isStopGuaranteed: Bool
//            
//            public init(from decoder: Decoder) throws {
//                let container = try decoder.container(keyedBy: CodingKeys.self)
//                
//                if let limitLevel = try container.decodeIfPresent(Double.self, forKey: .limitLevel) {
//                    self.limit = API.Position.Boundary.Limit.position(limitLevel)
//                } else if let limitDistance = try container.decodeIfPresent(Double.self, forKey: .limitDistance) {
//                    self.limit = API.Position.Boundary.Limit.distance(limitDistance)
//                } else {
//                    self.limit = nil
//                }
//                
//                if let stopLevel = try container.decodeIfPresent(Double.self, forKey: .stopLevel) {
//                    self.stop = API.Position.Boundary.Stop.position(stopLevel)
//                } else if let stopDistance = try container.decodeIfPresent(Double.self, forKey: .stopDistance) {
//                    self.stop = API.Position.Boundary.Stop.distance(stopDistance)
//                } else {
//                    self.stop = nil
//                }
//                
//                guard self.stop != nil else {
//                    self.isTrailingStop = false
//                    self.isStopGuaranteed = false; return
//                }
//                
//                self.isTrailingStop = try container.decodeIfPresent(Bool.self, forKey: .isTrailingStop) ?? false
//                self.isStopGuaranteed = try container.decodeIfPresent(Bool.self, forKey: .isStopGuaranteed) ?? false
//                
//            }
//            
//            private enum CodingKeys: String, CodingKey {
//                case limitLevel, limitDistance
//                case stopLevel, stopDistance
//                case isTrailingStop = "trailingStop"
//                case isStopGuaranteed = "guaranteedStop"
//            }
//        }
//        
//        /// Profit value and currency.
//        public struct Profit: CustomStringConvertible {
//            /// The actual profit value (it can be negative).
//            public let value: Double
//            /// The profit currency.
//            public let currency: String
//            
//            fileprivate init(value: Double, currency: String) {
//                self.value = value
//                self.currency = currency
//            }
//            
//            public var description: String {
//                return "\(self.currency)\(self.value)"
//            }
//        }
//    }
//}
//
//extension API.Response.Confirmation {
//    /// Rejected position confirmation.
//    public struct Rejected: APIResponseConfirmation, Decodable {
//        public let identifier: String
//        public let reference: String
//        public let date: Date
//        public let isAccepted: Bool
//        /// Describes the error condition for the specified trading operation.
//        public let reason: Reason
//        
//        public init(from decoder: Decoder) throws {
//            let confirmation = try API.Response.Confirmation(from: decoder)
//            self.identifier = confirmation.identifier
//            self.reference = confirmation.reference
//            self.date = confirmation.date
//            self.isAccepted = confirmation.isAccepted
//            
//            let container = try decoder.container(keyedBy: CodingKeys.self)
//            self.reason = try container.decode(Reason.self, forKey: .reason)
//        }
//        
//        private enum CodingKeys: String, CodingKey {
//            case reason
//        }
//        
//        /// Description of trading operation error/success.
//        public enum Reason: String, Decodable {
//            // The operation completed successfully.
//            // case success = "SUCCESS"
//            /// The operation resulted in an unknown result condition. Check transaction history or contact support for further information.
//            case unknown = "UNKNOWN"
//            /// An error has occurred but no detailed information is available. Check transaction history or contact support for further information.
//            case generalError = "GENERAL_ERROR"
//            
//            /// The deal has been rejected because of an existing position. Either set the 'force open' to be true or cancel opposing position.
//            case alreadyExistingPosition = "POSITION_ALREADY_EXISTS_IN_OPPOSITE_DIRECTION"
//            /// The epic is due to expire shortly, client should deal in the next available contract.
//            case closingMarket = "MARKET_CLOSING"
//            /// The market is currently closed.
//            case closedMarket = "MARKET_CLOSED"
//            /// The market is currently closed with edits.
//            case closedMarketEdits = "MARKET_CLOSED_WITH_EDITS"
//            /// Resubmitted request does not match the original order.
//            case conflictingOrder = "CONFLICTING_ORDER"
//            /// The account is not enabled to trade
//            case disabledAccount = "ACCOUNT_NOT_ENABLED_TO_TRADING"
//            /// The order has been rejected as it is a duplicate of a previously issued order.
//            case duplicatedOrder = "DUPLICATE_ORDER_ERROR"
//            /// Exchange check failed. Please call in for assistance.
//            case failedExchanged = "EXCHANGE_MANUAL_OVERRIDE"
//            /// Cannot close this position. Either the position no longer exists, or the size available to close is less than the size specified.
//            case failedPositionClose = "POSITION_NOT_AVAILABLE_TO_CLOSE"
//            /// Invalid attempt to submit a spreadbet trade on a CFD account.
//            case failedSpreadbetOpen = "REJECT_SPREADBET_ORDER_ON_CFD_ACCOUNT"
//            /// The requested market was not found.
//            case instrumentNotFound = "INSTRUMENT_NOT_FOUND"
//            /// The account has not enough funds available for the requested trade.
//            case insufficientFunds = "INSUFFICIENT_FUNDS"
//            /// The requested operation has been attempted on the wrong direction.
//            case invalidDirection = "WRONG_SIDE_OF_MARKET"
//            /// Order expiry is less than the sprint market's minimum expiry. Check the sprint market's market details for the allowable expiries.
//            case invalidExpirationDateMinimum = "EXPIRY_LESS_THAN_SPRINT_MARKET_MIN_EXPIRY"
//            /// The expiry of the position would have fallen after the closing time of the market.
//            case invalidExpirationDatePlace = "SPRINT_MARKET_EXPIRY_AFTER_MARKET_CLOSE"
//            /// The working order has been set to expire on a past date.
//            case invalidGoodTillDate = "GOOD_TILL_DATE_IN_THE_PAST"
//            /// Instrument has an error.
//            ///
//            /// Check the order's currency is the instrument's currency (see the market's details); otherwise please contact support.
//            case invalidInstrument = "CONTACT_SUPPORT_INSTRUMENT_ERROR"
//            /// The limit level you have requested is closer to the market level than the existing stop. When the market is closed you can only move the limit order further away from the current market level.
//            case invalidLevelLimitAway = "MOVE_AWAY_ONLY_LIMIT"
//            /// The deal has been rejected because the limit level is inconsistent with current market price given the direction.
//            case invalidLevelLimitWrongSide = "LIMIT_ORDER_WRONG_SIDE_OF_MARKET"
//            /// The stop level you have requested is closer to the market level than the existing stop level. When the market is closed you can only move the stop level further away from the current market level.
//            case invalidLevelStopAway = "MOVE_AWAY_ONLY_STOP"
//            /// The market level has moved and has been rejected
//            case invalidMarketLevel = "LEVEL_TOLERANCE_ERROR"
//            /// Order declined during margin checks Check available funds.
//            case invalidMargin = "MARGIN_ERROR"
//            /// The order level you have requested is moving closer to the market level than the exisiting order level. When the market is closed you can only move the order further away from the current market level.
//            case invalidOrderLevelAway = "MOVE_AWAY_ONLY_TRIGGER_LEVEL"
//            /// The level of the attached stop or limit is not valid.
//            case invalidOrderLevel = "ATTACHED_ORDER_LEVEL_ERROR"
//            /// Invalid attempt to submit a CFD trade on a spreadbet account.
//            case invalidOrderCFD = "REJECT_CFD_ORDER_ON_SPREADBET_ACCOUNT"
//            /// Opening CR position in opposite direction to existing CR position not allowed.
//            case invalidPositionCR = "OPPOSING_DIRECTION_ORDERS_NOT_ALLOWED"
//            /// The order size exceeds the instrument's maximum configured value for auto-hedging the exposure of a deal.
//            case invalidSizeMax = "MAX_AUTO_SIZE_EXCEEDED"
//            /// The order size is too small.
//            case invalidSizeMin = "MINIMUM_ORDER_SIZE_ERROR"
//            /// Sorry we are unable to process this order. The stop or limit level you have requested is not a valid trading level in the underlying market.
//            case invalidSpace = "CR_SPACING"
//            /// The submitted strike level is invalid.
//            case invalidStrikeLevel = "STRIKE_LEVEL_TOLERANCE"
//            /// The trailing stop value is invalid.
//            case invalidTrailingStop = "ATTACHED_ORDER_TRAILING_STOP_ERROR"
//            /// Cannot change the stop type.
//            case immutableStopType = "CANNOT_CHANGE_STOP_TYPE"
//            /// The manual order timeout limit has been reached.
//            case manualOrderTimeout = "MANUAL_ORDER_TIMEOUT"
//            /// The market is currently offline.
//            case marketOffline = "MARKET_OFFLINE"
//            /// The market has been rolled to the next period.
//            case marketRolled = "MARKET_ROLLED"
//            /// We are not taking opening deals on a Controlled Risk basis on this market.
//            case openTradesUnavailable = "CLOSING_ONLY_TRADES_ACCEPTED_ON_THIS_MARKET"
//            /// Order declined; please contact Support.
//            case orderDeclined = "ORDER_DECLINED"
//            /// The order is locked and cannot be edited by the user.
//            case orderLocked = "ORDER_LOCKED"
//            /// The order has not been found.
//            case orderNotFound = "ORDER_NOT_FOUND"
//            /// The total position size at this stop level is greater than the size allowed on this market. Please reduce the size of the order.
//            case overflowSize = "OVER_NORMAL_MARKET_SIZE"
//            /// The total size of deals placed on this market in a short period has exceeded our limits. Please wait before attempting to open further positions on this market.
//            case platformLimitReached = "FINANCE_REPEAT_DEALING"
//            /// The market can only be traded over the phone.
//            case phoneOnlyMarket = "MARKET_PHONE_ONLY"
//            /// The position has not been found.
//            case positionNotFound = "POSITION_NOT_FOUND"
//            /// Ability to force open in different currencies on same market not allowed.
//            case prohibitedForceOpen = "FORCE_OPEN_ON_SAME_MARKET_DIFFERENT_CURRENCY"
//            /// The requested market is not allowed to this account.
//            case prohibitedMarket = "MARKET_UNAVAILABLE_TO_CLIENT"
//            /// The epic does not support 'Market' order type.
//            case prohibitedMarketOrders = "MARKET_ORDERS_NOT_ALLOWED_ON_INSTRUMENT"
//            /// The deal has been rejected to avoid having long and short open positions on the same market or having long and short open positions and working orders on the same epic.
//            case prohibitedOpposingPositions = "OPPOSING_POSITIONS_NOT_ALLOWED"
//            /// The market does not allow opening shorting positions.
//            case prohibitedShorting = "MARKET_NOT_BORROWABLE"
//            /// The market does not allow stop or limit attached orders.
//            case prohibitStopLimit = "STOP_OR_LIMIT_NOT_ALLOWED"
//            /// The order requires a stop.
//            case requiredStop = "STOP_REQUIRED_ERROR"
//            /// The market or the account do not allow for trailing stops.
//            case prohibitedTrailingStop = "TRAILING_STOP_NOT_ALLOWED"
//            /// Order size is not an increment of the value specified for the market.
//            case sizeIncrement = "SIZE_INCREMENT"
//            /// Position cannot be cancelled. Check transaction history or contact support for further information.
//            case uncancellablePosition = "POSITION_NOT_AVAILABLE_TO_CANCEL"
//            /// Position cannot be deleted as it has been partially closed.
//            case unremovablePartiallyClosedPosition = "PARTIALY_CLOSED_POSITION_NOT_DELETED"
//            /// Cannot remove the stop.
//            case unremovableStop = "CANNOT_REMOVE_STOP"
//        }
//    }
//}
