import Combine
import Foundation

extension IG.Streamer.Request {
    /// Contains all functionality related to Streamer accounts.
    public struct Accounts {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        fileprivate unowned let streamer: IG.Streamer
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: IG.Streamer) {
            self.streamer = streamer
        }
    }
}

extension IG.Streamer.Request.Accounts {
    
    // MARK: ACCOUNT:ACCID
    
    /// Subscribes to the given account and returns in the response the specified attribute/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter account: The Account identifier.
    /// - parameter fields: The account properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(to account: IG.Account.Identifier, fields: Set<IG.Streamer.Account.Field>, snapshot: Bool = true) -> IG.Streamer.ContinuousPublisher<IG.Streamer.Account> {
        let item = "ACCOUNT:".appending(account.rawValue)
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .receive(on: self.streamer.queue)
            .tryMap { (update) in
                do {
                    return try .init(identifier: account, item: item, update: update)
                } catch var error as IG.Streamer.Error {
                    if case .none = error.item { error.item = item }
                    if case .none = error.fields { error.fields = properties }
                    throw error
                } catch let underlyingError {
                    throw IG.Streamer.Error.invalidResponse(.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: .reviewError)
                }
            }.mapError(IG.Streamer.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities
    
extension IG.Streamer.Account {
    /// Possible fields to subscribe to when querying account data.
    public enum Field: String, CaseIterable {
        /// Funds
        case funds = "FUNDS"
        /// Amount cash available to trade value, after account balance, profit and loss, and minimum deposit amount have been considered.
        case cashAvailable = "AVAILABLE_CASH"
        /// Amount of cash available to trade.
        case tradeAvailable = "AVAILABLE_TO_DEAL"
        /// Account minimum deposit value required for margins.
        case deposit = "DEPOSIT"
        
        /// Margin
        ///
        /// The amount required from a client (in addition to any deposit due) to cover losses when a price moves adversely.
        case margin = "MARGIN"
        /// Margin for limited risk.
        case marginLimitedRisk = "MARGIN_LR"
        /// Margin for non-limited risk.
        case marginNonLimitedRisk = "MARGIN_NLR"
        
        /// Equity.
        case equity = "EQUITY"
        /// Equity used.
        case equityUsed = "EQUITY_USED"
        
        /// Account profit and loss value.
        case profitLoss = "PNL"
        /// Profit/Loss for limited risk.
        case profitLossLimitedRisk = "PNL_LR"
        /// Profit/Loss for non-limited risk.
        case profitLossNonLimitedRisk = "PNL_NLR"
    }
}

extension Set where Element == IG.Streamer.Account.Field {
    /// Returns all queryable fields.
    public static var all: Self {
        return .init(Element.allCases)
    }
}

// MARK: Response Entities

extension IG.Streamer {
    /// Latest information from a user account.
    public struct Account {
        /// Account identifier.
        public let identifier: IG.Account.Identifier
        /// Account equity.
        public let equity: Self.Equity
        /// Account funds.
        public let funds: Self.Funds
        /// Account margins.
        public let margins: Self.Margins
        /// Account Profit and Loss values.
        public let profitLoss: Self.ProfitLoss
        
        internal init(identifier: IG.Account.Identifier, item: String, update: [String:IG.Streamer.Subscription.Update]) throws {
            typealias E = IG.Streamer.Error
            
            self.identifier = identifier
            do {
                self.equity = try .init(update: update)
                self.funds = try .init(update: update)
                self.margins = try .init(update: update)
                self.profitLoss = try .init(update: update)
            } catch let error as IG.Streamer.Formatter.Update.Error {
                throw E.invalidResponse(E.Message.parsing(update: error), item: item, update: update, underlying: error, suggestion: E.Suggestion.fileBug)
            } catch let underlyingError {
                throw E.invalidResponse(E.Message.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: E.Suggestion.reviewError)
            }
        }
    }
}

extension IG.Streamer.Account {
    /// Account equity.
    public struct Equity {
        /// The real account equity.
        public let value: Decimal?
        /// The equity used.
        public let used: Decimal?
        
        fileprivate init(update: [String:IG.Streamer.Subscription.Update]) throws {
            typealias F = IG.Streamer.Account.Field
            typealias U = IG.Streamer.Formatter.Update
            
            self.value = try update[F.equity.rawValue]?.value.map(U.toDecimal)
            self.used = try update[F.equityUsed.rawValue]?.value.map(U.toDecimal)
        }
    }
    
    /// Account funds.
    public struct Funds {
        /// Funds total value.
        public let value: Decimal?
        /// Amount of cash available to trade value, after account balance, profit and loss, and minimum deposit amount have been considered.
        public let cashAvailable: Decimal?
        /// Amount of cash available to trade.
        public let tradeAvailable: Decimal?
        /// Account minimum deposit value required for margins.
        public let deposit: Decimal?
        
        fileprivate init(update: [String:IG.Streamer.Subscription.Update]) throws {
            typealias F = IG.Streamer.Account.Field
            typealias U = IG.Streamer.Formatter.Update
            
            self.value = try update[F.funds.rawValue]?.value.map(U.toDecimal)
            self.cashAvailable = try update[F.cashAvailable.rawValue]?.value.map(U.toDecimal)
            self.tradeAvailable = try update[F.tradeAvailable.rawValue]?.value.map(U.toDecimal)
            self.deposit = try update[F.deposit.rawValue]?.value.map(U.toDecimal)
        }
    }
    
    /// Account margins.
    public struct Margins {
        /// The account margin value.
        public let value: Decimal?
        /// Limited risk margin.
        public let limitedRisk: Decimal?
        /// Non-limited risk margin.
        public let nonLimitedRisk: Decimal?
        
        fileprivate init(update: [String:IG.Streamer.Subscription.Update]) throws {
            typealias F = IG.Streamer.Account.Field
            typealias U = IG.Streamer.Formatter.Update
            
            self.value = try update[F.margin.rawValue]?.value.map(U.toDecimal)
            self.limitedRisk = try update[F.marginLimitedRisk.rawValue]?.value.map(U.toDecimal)
            self.nonLimitedRisk = try update[F.marginNonLimitedRisk.rawValue]?.value.map(U.toDecimal)
        }
    }
    
    /// Profit and Loss values for the account.
    public struct ProfitLoss {
        /// Account PNL value.
        public let value: Decimal?
        /// Limited risk PNL value.
        public let limitedRisk: Decimal?
        /// Non-limited risk PNL value.
        public let nonLimitedRisk: Decimal?
        
        fileprivate init(update: [String:IG.Streamer.Subscription.Update]) throws {
            typealias F = IG.Streamer.Account.Field
            typealias U = IG.Streamer.Formatter.Update
            
            self.value = try update[F.profitLoss.rawValue]?.value.map(U.toDecimal)
            self.limitedRisk = try update[F.profitLossLimitedRisk.rawValue]?.value.map(U.toDecimal)
            self.nonLimitedRisk = try update[F.profitLossNonLimitedRisk.rawValue]?.value.map(U.toDecimal)
        }
    }
}

extension IG.Streamer.Account: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = IG.DebugDescription("Streamer Account (\(self.identifier))")
        result.append("equity", self.equity) {
            $0.append("value", $1.value)
            $0.append("used", $1.used)
        }
        
        result.append("funds", self.funds) {
            $0.append("value", $1.value)
            $0.append("cash available", $1.cashAvailable)
            $0.append("trade available", $1.tradeAvailable)
            $0.append("deposit", $1.deposit)
        }
        
        result.append("margins", self.margins) {
            $0.append("value", $1.value)
            $0.append("limited risk", $1.limitedRisk)
            $0.append("non limited risk", $1.nonLimitedRisk)
        }
        
        result.append("P&L", self.profitLoss) {
            $0.append("value", $1.value)
            $0.append("limited risk", $1.limitedRisk)
            $0.append("non limited risk", $1.nonLimitedRisk)
        }
        return result.generate()
    }
}
