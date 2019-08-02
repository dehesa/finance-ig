import ReactiveSwift
import Foundation

extension Streamer.Request.Accounts {
    
    // MARK: ACCOUNT:ACCID
    
    /// Subscribes to the given account and returns in the response the specified attribute/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter accountId: The Account identifier.
    /// - parameter fields: The account properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(to accountIdentifier: String, _ fields: Set<Streamer.Account.Field>, snapshot: Bool = true) -> SignalProducer<Streamer.Account,Streamer.Error> {
        let item = "MARKET:".appending(accountIdentifier)
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .attemptMap { (update) in
                do {
                    let account = try Streamer.Account(identifier: accountIdentifier, item: item, update: update)
                    return .success(account)
                } catch let error as Streamer.Error {
                    return .failure(error)
                } catch let error {
                    return .failure(.invalidResponse(item: item, fields: update, message: "An unkwnon error occur will parsing an account update.\nError: \(error)"))
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

// MARK: Response Entities

extension Streamer {
    /// Latest information from a user account.
    public struct Account {
        /// Account identifier.
        public let identifier: String
        /// Account equity.
        public let equity: Self.Equity
        /// Account funds.
        public let funds: Self.Funds
        /// Account margins.
        public let margins: Self.Margins
        /// Account Profit and Loss values.
        public let profitLoss: Self.ProfitLoss
        
        internal init(identifier: String, item: String, update: [String:String]) throws {
            self.identifier = identifier
            do {
                self.equity = try .init(update: update)
                self.funds = try .init(update: update)
                self.margins = try .init(update: update)
                self.profitLoss = try .init(update: update)
            } catch let error as Streamer.Formatter.Update.Error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An error was encountered when parsing the value \"\(error.value)\" from a \"String\" to a \"\(error.type)\".")
            } catch let error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An unknown error was encountered when parsing the updated payload.\nError: \(error)")
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
        
        fileprivate init(update: [String:String]) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Formatter.Update
            
            self.value = try update[F.equity.rawValue].map(U.toDecimal)
            self.used = try update[F.equityUsed.rawValue].map(U.toDecimal)
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
        
        fileprivate init(update: [String:String]) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Formatter.Update
            
            self.value = try update[F.funds.rawValue].map(U.toDecimal)
            self.cashAvailable = try update[F.cashAvailable.rawValue].map(U.toDecimal)
            self.tradeAvailable = try update[F.tradeAvailable.rawValue].map(U.toDecimal)
            self.deposit = try update[F.deposit.rawValue].map(U.toDecimal)
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
        
        fileprivate init(update: [String:String]) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Formatter.Update
            
            self.value = try update[F.margin.rawValue].map(U.toDecimal)
            self.limitedRisk = try update[F.marginLimitedRisk.rawValue].map(U.toDecimal)
            self.nonLimitedRisk = try update[F.marginNonLimitedRisk.rawValue].map(U.toDecimal)
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
        
        fileprivate init(update: [String:String]) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Formatter.Update
            
            self.value = try update[F.profitLoss.rawValue].map(U.toDecimal)
            self.limitedRisk = try update[F.profitLossLimitedRisk.rawValue].map(U.toDecimal)
            self.nonLimitedRisk = try update[F.profitLossNonLimitedRisk.rawValue].map(U.toDecimal)
        }
    }
}
