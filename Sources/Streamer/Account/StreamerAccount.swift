import ReactiveSwift
import Foundation

extension Streamer {
    /// Subscribes to the given account and returns in the response the specified attribute/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter accountId: The Account identifier.
    /// - parameter fields: The account properties/fields bieng targeted.
    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically or whether it should wait for the user to explicitly call `connect()`.
    /// - returns: Signal producer that can be started at any time; when which a subscription to the server will be executed.
    public func subscribe(account accountId: String, fields: Set<Request.Account>, autoconnect: Bool = true) -> SignalProducer<Response.Account,Streamer.Error> {
        return self.subscriptionProducer({ (streamer) -> (String, StreamerSubscriptionSession) in
            let label = streamer.queue.label + ".account." + accountId

            let itemName = Request.Account.itemName(identifier: accountId)
            let subscriptionSession = streamer.session.makeSubscriptionSession(mode: .merge, items: [itemName], fields: fields)
            
            return (label, subscriptionSession)
        }, autoconnect: autoconnect) { (input, event) in
            switch event {
            case .updateReceived(let update):
                do {
                    let response = try Response.Account(update: update)
                    input.send(value: response)
                } catch let error {
                    input.send(error: error as! Streamer.Error)
                }
            case .unsubscribed:
                input.sendCompleted()
            case .subscriptionFailed(let underlyingError):
                let error: Streamer.Error = .subscriptionFailed(to: Request.Account.itemName(identifier: accountId), fields: fields.map { $0.rawValue }, error: underlyingError)
                input.send(error: error)
            case .subscriptionSucceeded, .updateLost(_,_):
                break
            }
        }
    }
    
    /// Subscribes to the given accounts and returns the specified attributes/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter accountIds: The Account identifiers.
    /// - parameter fields: The account properties/fields bieng targeted.
    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically or whether it should wait for the user to explicitly call `connect()`.
    /// - returns: Signal producer that can be started at any time; when which a subscription to the server will be executed.
    public func subscribe(accounts accountIds: [String], fields: Set<Request.Account>, autoconnect: Bool = true) -> SignalProducer<(String,Response.Account),Streamer.Error> {
        return self.subscriptionProducer({ (streamer) -> (String, StreamerSubscriptionSession) in
            guard accountIds.isUniquelyLaden else {
                throw Streamer.Error.invalidRequest(message: "You need to subscribe to at least one account.")
            }
            
            let suffix = accountIds.joined(separator: "|")
            let label = streamer.queue.label + ".accounts." + suffix
            
            let itemNames = accountIds.map { Request.Account.itemName(identifier: $0) }
            let subscriptionSession = streamer.session.makeSubscriptionSession(mode: .merge, items: Set(itemNames), fields: fields)
            
            return (label, subscriptionSession)
        }, autoconnect: autoconnect) { (input, event) in
            switch event {
            case .updateReceived(let update):
                do {
                    guard let accountId = Request.Account.accountId(itemName: update.item, requestedAccounts: accountIds) else {
                        throw Streamer.Error.invalidResponse(item: update.item, fields: update.all, message: "The item name couldn't be identified.")
                    }
                    let response = try Response.Account(update: update)
                    input.send(value: (accountId, response))
                } catch let error {
                    input.send(error: error as! Streamer.Error)
                }
            case .unsubscribed:
                input.sendCompleted()
            case .subscriptionFailed(let underlyingError):
                let items = accountIds.joined(separator: ", ")
                let error: Streamer.Error = .subscriptionFailed(to: items, fields: fields.map { $0.rawValue }, error: underlyingError)
                input.send(error: error)
            case .subscriptionSucceeded, .updateLost(_,_):
                break
            }
        }
    }
}

extension Streamer.Request {
    /// Possible fields to subscribe to when querying account data.
    public enum Account: String, StreamerRequestItemNamePrefixable, StreamerFieldKeyable, CaseIterable {
        /// Funds
        case funds = "FUNDS"
        /// Amount cash available to trade value, after account balance, profit and loss, and minimum deposit amount have been considered.
        case cashAvailable = "AVAILABLE_CASH"
        /// Amount of cash available to trade.
        case tradeAvailable = "AVAILABLE_TO_DEAL"
        /// Margin
        ///
        /// The amount required from a client (in addition to any deposit due) to cover losses when a price moves adversely.
        case margin = "MARGIN"
        /// Margin for limited risk.
        case marginLimitedRisk = "MARGIN_LR"
        /// Margin for non-limited risk.
        case marginNonLimitedRisk = "MARGIN_NLR"
        /// Account minimum deposit value required for margins.
        case deposit = "DEPOSIT"
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
        
        internal static var prefix: String {
            return "ACCOUNT:"
        }
        
        fileprivate static func accountId(itemName: String, requestedAccounts accountIds: [String]) -> String? {
            guard itemName.hasPrefix(self.prefix) else { return nil }
            let identifier = String(itemName.dropFirst(self.prefix.count))
            return accountIds.find { $0 == identifier }
        }
        
        public var keyPath: PartialKeyPath<Streamer.Response.Account> {
            switch self {
            case .funds:                    return \Response.funds.value
            case .cashAvailable:            return \Response.funds.cashAvailable
            case .tradeAvailable:           return \Response.funds.tradeAvailable
            case .margin:                   return \Response.margins.value
            case .marginLimitedRisk:        return \Response.margins.limitedRisk
            case .marginNonLimitedRisk:     return \Response.margins.nonLimitedRisk
            case .deposit:                  return \Response.margins.deposit
            case .equity:                   return \Response.equity.value
            case .equityUsed:               return \Response.equity.used
            case .profitLoss:               return \Response.profitLoss.value
            case .profitLossLimitedRisk:    return \Response.profitLoss.limitedRisk
            case .profitLossNonLimitedRisk: return \Response.profitLoss.nonLimitedRisk
            }
        }
    }
}

extension Streamer.Response {
    /// Response for an Account stream package.
    public struct Account: StreamerResponse, StreamerUpdatable {
        public typealias Field = Streamer.Request.Account
        public let fields: Account.Update
        /// Account funds.
        public let funds: Funds
        /// Account margins.
        public let margins: Margins
        /// Account equity.
        public let equity: Equity
        /// Account Profit and Loss values.
        public let profitLoss: ProfitLoss
        
        internal init(update: StreamerSubscriptionUpdate) throws {
            let (values, fields) = try Update.make(update)
            self.fields = fields
            
            self.funds = Funds(received: values)
            self.margins = Margins(received: values)
            self.equity = Equity(received: values)
            self.profitLoss = ProfitLoss(received: values)
        }
    }
}

extension Streamer.Response.Account {
    /// Account funds.
    public struct Funds {
        /// Funds total value.
        public let value: Double?
        /// Amount of cash available to trade value, after account balance, profit and loss, and minimum deposit amount have been considered.
        public let cashAvailable: Double?
        /// Amount of cash available to trade.
        public let tradeAvailable: Double?
        
        fileprivate init(received: [Field:String]) {
            self.value = received[.funds].flatMap { Double($0) }
            self.cashAvailable = received[.cashAvailable].flatMap { Double($0) }
            self.tradeAvailable = received[.tradeAvailable].flatMap { Double($0) }
        }
    }
    
    /// Profit and Loss values for the account.
    public struct ProfitLoss {
        /// Account PNL value.
        public let value: Double?
        /// Limited risk PNL value.
        public let limitedRisk: Double?
        /// Non-limited risk PNL value.
        public let nonLimitedRisk: Double?
        
        fileprivate init(received: [Field:String]) {
            self.value = received[.profitLoss].flatMap { Double($0) }
            self.limitedRisk = received[.profitLossLimitedRisk].flatMap { Double($0) }
            self.nonLimitedRisk = received[.profitLossNonLimitedRisk].flatMap { Double($0) }
        }
    }
    
    /// Account margins.
    public struct Margins {
        /// The account margin value.
        public let value: Double?
        /// Limited risk margin.
        public let limitedRisk: Double?
        /// Non-limited risk margin.
        public let nonLimitedRisk: Double?
        /// Account minimum deposit value required for margins.
        public let deposit: Double?
        
        fileprivate init(received: [Field:String]) {
            self.value = received[.margin].flatMap { Double($0) }
            self.limitedRisk = received[.marginLimitedRisk].flatMap { Double($0) }
            self.nonLimitedRisk = received[.marginNonLimitedRisk].flatMap { Double($0) }
            self.deposit = received[.deposit].flatMap { Double($0) }
        }
    }
    
    /// Account equity.
    public struct Equity {
        /// The real account equity.
        public let value: Double?
        /// The equity used.
        public let used: Double?
        
        fileprivate init(received: [Field:String]) {
            self.value = received[.equity].flatMap { Double($0) }
            self.used = received[.equityUsed].flatMap { Double($0) }
        }
    }
}
