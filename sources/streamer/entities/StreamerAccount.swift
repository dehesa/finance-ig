#if os(macOS) && arch(x86_64)
import Lightstreamer_macOS_Client
#elseif os(macOS)

#elseif os(iOS)
import Lightstreamer_iOS_Client
#elseif os(tvOS)
import Lightstreamer_tvOS_Client
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
        /// Account P&L value.
        public let value: Decimal64?
        /// Limited risk P&L value.
        public let limitedRisk: Decimal64?
        /// Non-limited risk P&L value.
        public let nonLimitedRisk: Decimal64?
    }
}

// MARK: -

#if (os(macOS) && arch(x86_64)) || os(iOS) || os(tvOS)

fileprivate typealias F = Streamer.Account.Field

internal extension Streamer.Account {
    /// - throws: `IG.Error` exclusively.
    init(id: IG.Account.Identifier, update: LSItemUpdate, fields: Set<Field>) throws {
        self.id = id
        self.funds = fields.contains(F.funds) ? try update.decodeIfPresent(Decimal64.self, forKey: F.funds) : nil
        self.equity = try .init(update: update, fields: fields)
        self.margins = try .init(update: update, fields: fields)
        self.profitLoss = try .init(update: update, fields: fields)
    }
}

fileprivate extension Streamer.Account.Equity {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate, fields: Set<Streamer.Account.Field>) throws {
        self.value = fields.contains(F.equity) ? try update.decodeIfPresent(Decimal64.self, forKey: F.equity) : nil
        self.used = fields.contains(F.equityUsed) ? try update.decodeIfPresent(Decimal64.self, forKey: F.equityUsed) : nil
        self.cashAvailable = fields.contains(F.cashAvailable) ? try update.decodeIfPresent(Decimal64.self, forKey: F.cashAvailable) : nil
        self.tradeAvailable = fields.contains(F.tradeAvailable) ? try update.decodeIfPresent(Decimal64.self, forKey: F.tradeAvailable) : nil
    }
}

fileprivate extension Streamer.Account.Margins {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate, fields: Set<Streamer.Account.Field>) throws {
        self.value = fields.contains(F.margin) ? try update.decodeIfPresent(Decimal64.self, forKey: F.margin) : nil
        self.limitedRisk = fields.contains(F.marginLimitedRisk) ? try update.decodeIfPresent(Decimal64.self, forKey: F.marginLimitedRisk) : nil
        self.nonLimitedRisk = fields.contains(F.marginNonLimitedRisk) ? try update.decodeIfPresent(Decimal64.self, forKey: F.marginNonLimitedRisk) : nil
        self.deposit = fields.contains(F.deposit) ? try update.decodeIfPresent(Decimal64.self, forKey: F.deposit): nil
    }
}

fileprivate extension Streamer.Account.ProfitLoss {
    /// - throws: `IG.Error` exclusively.
    init(update: LSItemUpdate, fields: Set<Streamer.Account.Field>) throws {
        self.value = fields.contains(F.profitLoss) ? try update.decodeIfPresent(Decimal64.self, forKey: F.profitLoss) : nil
        self.limitedRisk = fields.contains(F.profitLossLimitedRisk) ? try update.decodeIfPresent(Decimal64.self, forKey: F.profitLossLimitedRisk) : nil
        self.nonLimitedRisk = fields.contains(F.profitLossNonLimitedRisk) ? try update.decodeIfPresent(Decimal64.self, forKey: F.profitLossNonLimitedRisk) : nil
    }
}

#else

internal extension Streamer.Account {
    /// - throws: `IG.Error` exclusively.
    init(id: IG.Account.Identifier, update: Any, fields: Set<Field>) throws {
        fatalError()
    }
}

#endif
