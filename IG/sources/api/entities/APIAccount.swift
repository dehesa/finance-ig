import Decimals

extension API {
    /// Client account.
    public struct Account: Identifiable, Decodable {
        /// Account identifier.
        public let id: IG.Account.Identifier
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
        public let currencyCode: Currency.Code
        /// Permission of money transfers in and out of the account.
        public let transfersAllowed: (`in`: Bool, out: Bool)
        /// Account balance.
        public let balance: Self.Balance
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _Keys.self)
            self.id = try container.decode(IG.Account.Identifier.self, forKey: .identifier)
            self.name = try container.decode(String.self, forKey: .name)
            self.alias = try container.decodeIfPresent(String.self, forKey: .alias)
            self.status = try container.decode(Status.self, forKey: .status)
            self.isDefault = try container.decode(Bool.self, forKey: .preferred)
            self.currencyCode = try container.decode(Currency.Code.self, forKey: .currencyCode)
            self.transfersAllowed = (
                try container.decode(Bool.self, forKey: .transfersIn),
                try container.decode(Bool.self, forKey: .transfersOut)
            )
            self.type = try container.decode(Kind.self, forKey: .type)
            self.balance = try container.decode(Balance.self, forKey: .balance)
        }
        
        private enum _Keys: String, CodingKey {
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

extension API.Account {
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
        public let value: Decimal64
        /// Minimum deposit amount required for margins.
        public let deposit: Decimal64
        /// Profit & Loss amount.
        public let profitLoss: Decimal64
        /// Amount available for trading.
        public let available: Decimal64
        
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
        @available(*, unavailable)
        private init?() { fatalError() }
        
        private enum CodingKeys: String, CodingKey {
            case trailingStops = "trailingStopsEnabled"
        }
    }
}
