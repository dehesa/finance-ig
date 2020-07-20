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
    public func subscribe(account: IG.Account.Identifier, fields: Set<Streamer.Account.Field>, snapshot: Bool = true) -> AnyPublisher<Streamer.Account,Streamer.Error> {
        let item = "ACCOUNT:".appending(account.rawValue)
        let properties = fields.map { $0.rawValue }
        
        return self.streamer.channel
            .subscribe(on: self.streamer.queue, mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .tryMap { (update) in
                do {
                    return try .init(identifier: account, item: item, update: update)
                } catch var error as Streamer.Error {
                    if case .none = error.item { error.item = item }
                    if case .none = error.fields { error.fields = properties }
                    throw error
                } catch let underlyingError {
                    throw Streamer.Error.invalidResponse(.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: .reviewError)
                }
            }.mapError(Streamer.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities
    
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

// MARK: Response Entities

extension Streamer {
    /// Latest information from a user account.
    public struct Account {
        /// Account identifier.
        public let identifier: IG.Account.Identifier
        /// Total cash balance on your account (not accounting the running profit/losses).
        public let funds: Decimal64?
        /// Net value of your account (`funds` + running `profitLoss`).
        public let equity: Self.Equity
        /// Minimum required Equity to maintain your position.
        public let margins: Self.Margins
        /// Aggregate profit or loss of all open positions.
        public let profitLoss: Self.ProfitLoss
        
        internal init(identifier: IG.Account.Identifier, item: String, update: Streamer.Packet) throws {
            typealias E = Streamer.Error
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Update
            
            self.identifier = identifier
            do {
                self.funds = try update[F.funds.rawValue]?.value.map(U.toDecimal)
                self.equity = try .init(update: update)
                self.margins = try .init(update: update)
                self.profitLoss = try .init(update: update)
            } catch let error as Streamer.Update.Error {
                throw E.invalidResponse(E.Message.parsing(update: error), item: item, update: update, underlying: error, suggestion: E.Suggestion.fileBug)
            } catch let underlyingError {
                throw E.invalidResponse(E.Message.unknownParsing, item: item, update: update, underlying: underlyingError, suggestion: E.Suggestion.reviewError)
            }
        }
    }
}

extension Streamer.Account {
    /// Account equity calculating the funds plus the running profit/losses.
    public struct Equity {
        /// Net value of your account (`funds` + running `profitLoss`).
        public let value: Decimal64?
        /// Percentage of `equity.value` used by the margin.
        ///
        /// Your positions could be automatically closed if this reaches 100%.
        public let used: Decimal64?
        /// Amount of cash available to trade value, after account balance, profit and loss, and minimum deposit amount have been considered.
        public let cashAvailable: Decimal64?
        /// Amount of cash available to trade.
        public let tradeAvailable: Decimal64?
        
        fileprivate init(update: Streamer.Packet) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Update
            
            self.value = try update[F.equity.rawValue]?.value.map(U.toDecimal)
            self.used = try update[F.equityUsed.rawValue]?.value.map(U.toDecimal)
            self.cashAvailable = try update[F.cashAvailable.rawValue]?.value.map(U.toDecimal)
            self.tradeAvailable = try update[F.tradeAvailable.rawValue]?.value.map(U.toDecimal)
        }
    }
    
    /// Account margins.
    public struct Margins {
        /// The account margin value.
        public let value: Decimal64?
        /// Limited risk margin.
        public let limitedRisk: Decimal64?
        /// Non-limited risk margin.
        public let nonLimitedRisk: Decimal64?
        /// Account minimum deposit value required for margins.
        public let deposit: Decimal64?
        
        fileprivate init(update: Streamer.Packet) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Update
            
            self.value = try update[F.margin.rawValue]?.value.map(U.toDecimal)
            self.limitedRisk = try update[F.marginLimitedRisk.rawValue]?.value.map(U.toDecimal)
            self.nonLimitedRisk = try update[F.marginNonLimitedRisk.rawValue]?.value.map(U.toDecimal)
            self.deposit = try update[F.deposit.rawValue]?.value.map(U.toDecimal)
        }
    }
    
    /// Profit and Loss values for the account.
    public struct ProfitLoss {
        /// Account PNL value.
        public let value: Decimal64?
        /// Limited risk PNL value.
        public let limitedRisk: Decimal64?
        /// Non-limited risk PNL value.
        public let nonLimitedRisk: Decimal64?
        
        fileprivate init(update: Streamer.Packet) throws {
            typealias F = Streamer.Account.Field
            typealias U = Streamer.Update
            
            self.value = try update[F.profitLoss.rawValue]?.value.map(U.toDecimal)
            self.limitedRisk = try update[F.profitLossLimitedRisk.rawValue]?.value.map(U.toDecimal)
            self.nonLimitedRisk = try update[F.profitLossNonLimitedRisk.rawValue]?.value.map(U.toDecimal)
        }
    }
}
