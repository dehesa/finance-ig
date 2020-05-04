import Foundation

extension IG.API {
    /// Client account.
    public struct Account: Decodable {
        /// Account identifier.
        public let identifier: IG.Account.Identifier
        /// Account name.
        public let name: String
        /// Account alias.
        public let alias: String?
        /// Account type.
        public let type: Self.Kind
        /// Account status.
        public let status: Self.Status
        /// Default/Preferred login account.
        public let isDefault: Bool
        /// Account currency.
        public let currencyCode: IG.Currency.Code
        /// Permission of money transfers in and out of the account.
        public let transfersAllowed: (`in`: Bool, out: Bool)
        /// Account balance.
        public let balance: Self.Balance
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _CodingKeys.self)
            self.identifier = try container.decode(IG.Account.Identifier.self, forKey: .identifier)
            self.name = try container.decode(String.self, forKey: .name)
            self.alias = try container.decodeIfPresent(String.self, forKey: .alias)
            self.status = try container.decode(Status.self, forKey: .status)
            self.isDefault = try container.decode(Bool.self, forKey: .preferred)
            self.currencyCode = try container.decode(IG.Currency.Code.self, forKey: .currencyCode)
            self.transfersAllowed = (
                try container.decode(Bool.self, forKey: .transfersIn),
                try container.decode(Bool.self, forKey: .transfersOut)
            )
            self.type = try container.decode(Kind.self, forKey: .type)
            self.balance = try container.decode(Balance.self, forKey: .balance)
        }
        
        private enum _CodingKeys: String, CodingKey {
            case identifier = "accountId"
            case name = "accountName"
            case alias = "accountAlias"
            case status, preferred
            case currencyCode = "currency"
            case transfersIn = "canTransferFrom"
            case transfersOut = "canTransferTo"
            case type = "accountType"
            case balance
        }
    }
}

extension IG.API.Account {
    /// Account status
    public enum Status: String, Decodable {
        case disable = "DISABLED"
        case enabled = "ENABLED"
        case suspended = "SUSPENDED_FROM_DEALING"
    }
    
    /// Account type.
    public enum Kind: String, Decodable {
        /// CFD (Contract for difference) account.
        case cfd = "CFD"
        /// Physical account.
        case physical = "PHYSICAL"
        /// Spread bet account.
        case spreadBet = "SPREADBET"
    }
    
    /// Account balances.
    public struct Balance: Decodable {
        /// Balance of funds in the account.
        public let value: Decimal
        /// Minimum deposit amount required for margins.
        public let deposit: Decimal
        /// Profit & Loss amount.
        public let profitLoss: Decimal
        /// Amount available for trading.
        public let available: Decimal
        
        private enum CodingKeys: String, CodingKey {
            case value = "balance"
            case deposit
            case profitLoss
            case available
        }
    }

    /// Account preferences.
    public struct Preferences: Decodable {
        /// Whether the user wants to be allowed to define trailing stop rules for his trade operations.
        ///
        /// A trailing stop is a type of stop order that moves automatically when the market moves in your favour, locking in gains while your position is open.
        public let trailingStops: Bool
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        private enum CodingKeys: String, CodingKey {
            case trailingStops = "trailingStopsEnabled"
        }
    }
}

extension IG.API.Account: IG.DebugDescriptable {
    internal static var printableDomain: String { "\(IG.API.printableDomain).\(Self.self)" }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("account ID", self.identifier)
        result.append("name", self.name)
        result.append("alias", self.alias)
        result.append("type", self.type)
        result.append("status", self.status)
        result.append("is default", self.isDefault)
        result.append("currency code", self.currencyCode)
        result.append("inbound transfers allowed", self.transfersAllowed.in)
        result.append("outbound transfers allowed", self.transfersAllowed.out)
        result.append("account balance", self.balance) {
            $0.append("funds", $1.value)
            $0.append("deposit", $1.deposit)
            $0.append("P&L", $1.profitLoss)
            $0.append("available", $1.available)
        }
        return result.generate()
    }
}
