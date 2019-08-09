import ReactiveSwift
import Foundation

extension Streamer.Request.Accounts {
    
    // MARK: ACCOUNT:ACCID
    
    /// Subscribes to the given account and returns in the response the specified attribute/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter account: The Account identifier.
    /// - parameter fields: The account properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(to account: IG.Account.Identifier, fields: Set<Streamer.Account.Field>, snapshot: Bool = true) -> SignalProducer<Streamer.Account,Streamer.Error> {
        let item = "ACCOUNT:".appending(account.rawValue)
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .attemptMap { (update) in
                do {
                    let account = try Streamer.Account(identifier: account, item: item, update: update)
                    return .success(account)
                } catch var error as Streamer.Error {
                    if case .none = error.item { error.item = item }
                    if case .none = error.fields { error.fields = properties }
                    return .failure(error)
                } catch let underlyingError {
                    let error = Streamer.Error(.invalidResponse, Streamer.Error.Message.unknownParsing, suggestion: Streamer.Error.Suggestion.reviewError, item: item, fields: properties, underlying: underlyingError)
                    return .failure(error)
                }
            }
    }
}

// MARK: - Supporting Entities

extension Streamer.Request {
    /// Contains all functionality related to Streamer accounts.
    public struct Accounts {
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
    
extension Streamer.Account {
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

extension Set where Element == Streamer.Account.Field {
    /// Returns all queryable fields.
    public static var all: Self {
        return .init(Element.allCases)
    }
}

// MARK: Response Entities

extension Streamer {
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
        
        internal init(identifier: IG.Account.Identifier, item: String, update: [String:Streamer.Subscription.Update]) throws {
            self.identifier = identifier
            do {
                self.equity = try .init(update: update)
                self.funds = try .init(update: update)
                self.margins = try .init(update: update)
                self.profitLoss = try .init(update: update)
            } catch let error as Streamer.Formatter.Update.Error {
                throw Streamer.Error.invalidResponse(Streamer.Error.Message.parsing(update: error), item: item, update: update, underlying: error, suggestion: Streamer.Error.Suggestion.bug)
            } catch let underlyingError {
                throw Streamer.Error.invalidResponse(Streamer.Error.Message.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: Streamer.Error.Suggestion.reviewError)
            }
        }
    }
}

extension Streamer.Account {
    /// Account equity.
    public struct Equity {
        /// The real account equity.
        public let value: Decimal?
        /// The equity used.
        public let used: Decimal?
        
        fileprivate init(update: [String:Streamer.Subscription.Update]) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Formatter.Update
            
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
        
        fileprivate init(update: [String:Streamer.Subscription.Update]) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Formatter.Update
            
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
        
        fileprivate init(update: [String:Streamer.Subscription.Update]) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Formatter.Update
            
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
        
        fileprivate init(update: [String:Streamer.Subscription.Update]) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Formatter.Update
            
            self.value = try update[F.profitLoss.rawValue]?.value.map(U.toDecimal)
            self.limitedRisk = try update[F.profitLossLimitedRisk.rawValue]?.value.map(U.toDecimal)
            self.nonLimitedRisk = try update[F.profitLossNonLimitedRisk.rawValue]?.value.map(U.toDecimal)
        }
    }
}

extension Streamer.Account: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result: String = self.identifier.rawValue
        result.append(prefix: "\n\t", name: "Equity", ":", " ")
        result.append(prefix: "\n\t\t", name: "value", ": ", self.equity.value)
        result.append(prefix: "\n\t\t", name: "used", ": ", self.equity.used)
        result.append(prefix: "\n\t", name: "Funds", ":", " ")
        result.append(prefix: "\n\t\t", name: "value", ": ", self.funds.value)
        result.append(prefix: "\n\t\t", name: "cash available", ": ", self.funds.cashAvailable)
        result.append(prefix: "\n\t\t", name: "trade available", ": ", self.funds.tradeAvailable)
        result.append(prefix: "\n\t\t", name: "deposit", ": ", self.funds.deposit)
        result.append(prefix: "\n\t", name: "Margins", ":", " ")
        result.append(prefix: "\n\t\t", name: "value", ": ", self.margins.value)
        result.append(prefix: "\n\t\t", name: "limited risk", ": ", self.margins.limitedRisk)
        result.append(prefix: "\n\t\t", name: "non limited risk", ": ", self.margins.nonLimitedRisk)
        result.append(prefix: "\n\t", name: "Profit & Loss", ":", " ")
        result.append(prefix: "\n\t\t", name: "value", ": ", self.profitLoss.value)
        result.append(prefix: "\n\t\t", name: "limited risk", ": ", self.profitLoss.limitedRisk)
        result.append(prefix: "\n\t\t", name: "non limited risk", ": ", self.profitLoss.nonLimitedRisk)
        return result
    }
}
