import Combine
import Decimals

extension Streamer.Request {
    /// Contains all functionality related to Streamer accounts.
    public struct Accounts {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        internal unowned let streamer: Streamer
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        @usableFromInline internal init(streamer: Streamer) { self.streamer = streamer }
    }
}

extension Streamer.Request.Accounts {
    
    // MARK: ACCOUNT:ACCID
    
    /// Subscribes to the given account and returns in the response the specified attribute/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter account: The Account identifier.
    /// - parameter fields: The account properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    /// - returns: Signal producer that can be started at any time.
    public func subscribe(account: IG.Account.Identifier, fields: Set<Streamer.Account.Field>, snapshot: Bool = true) -> AnyPublisher<Streamer.Account,IG.Error> {
        let item = "ACCOUNT:".appending(account.rawValue)
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(on: self.streamer.queue, mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .tryMap { try Streamer.Account(id: account, update: $0) }
            .mapStreamError(item: item, fields: fields)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities
    
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
    @_transparent public static var all: Self {
        .init(Element.allCases)
    }
}
