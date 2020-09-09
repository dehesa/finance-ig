#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#else
#error("OS currently not supported")
#endif
import Foundation
import Decimals

extension Streamer {
    /// Latest information from a user account.
    public struct Account: Identifiable {
        /// Account identifier.
        public let id: IG.Account.Identifier
        /// Total cash balance on your account (not accounting the running profit/losses).
        public let funds: Decimal64?
        /// Net value of your account (`funds` + running `profitLoss`).
        public let equity: Self.Equity
        /// Minimum required Equity to maintain your position.
        public let margins: Self.Margins
        /// Aggregate profit or loss of all open positions.
        public let profitLoss: Self.ProfitLoss
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
    }
}

extension Streamer.Account {
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
    }
}

extension Streamer.Account {
    /// Profit and Loss values for the account.
    public struct ProfitLoss {
        /// Account PNL value.
        public let value: Decimal64?
        /// Limited risk PNL value.
        public let limitedRisk: Decimal64?
        /// Non-limited risk PNL value.
        public let nonLimitedRisk: Decimal64?
    }
}

// MARK: -

fileprivate typealias F = Streamer.Account.Field

internal extension Streamer.Account {
    /// - throws: `IG.Error` exclusively.
    init(id: IG.Account.Identifier, update: LSItemUpdate) throws {
        self.id = id
        self.funds =  try update.decodeIfPresent(Decimal64.self, forKey: F.funds)
        self.equity = try .init(update: update)
        self.margins = try .init(update: update)
        self.profitLoss = try .init(update: update)
    }
}

fileprivate extension Streamer.Account.Equity {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate) throws {
        self.value = try update.decodeIfPresent(Decimal64.self, forKey: F.equity)
        self.used = try update.decodeIfPresent(Decimal64.self, forKey: F.equityUsed)
        self.cashAvailable = try update.decodeIfPresent(Decimal64.self, forKey: F.cashAvailable)
        self.tradeAvailable = try update.decodeIfPresent(Decimal64.self, forKey: F.tradeAvailable)
    }
}

fileprivate extension Streamer.Account.Margins {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate) throws {
        self.value = try update.decodeIfPresent(Decimal64.self, forKey: F.margin)
        self.limitedRisk = try update.decodeIfPresent(Decimal64.self, forKey: F.marginLimitedRisk)
        self.nonLimitedRisk = try update.decodeIfPresent(Decimal64.self, forKey: F.marginNonLimitedRisk)
        self.deposit = try update.decodeIfPresent(Decimal64.self, forKey: F.deposit)
    }
}

fileprivate extension Streamer.Account.ProfitLoss {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate) throws {
        self.value = try update.decodeIfPresent(Decimal64.self, forKey: F.profitLoss)
        self.limitedRisk = try update.decodeIfPresent(Decimal64.self, forKey: F.profitLossLimitedRisk)
        self.nonLimitedRisk = try update.decodeIfPresent(Decimal64.self, forKey: F.profitLossNonLimitedRisk)
    }
}
