import Decimals

extension API {
    /// Client account.
    public struct Account: Identifiable {
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
        public let currency: Currency.Code
        /// Permission of money transfers in and out of the account.
        public let transfersAllowed: (`in`: Bool, out: Bool)
        /// Account balance.
        public let balance: Self.Balance
    }
}

extension API.Account {
    /// Account type.
    public enum Kind {
        /// CFD (Contract for difference) account.
        case cfd
        /// Physical account.
        case physical
        /// Spread bet account.
        case spreadBet
    }
    
    /// Account status.
    public enum Status {
        /// The account is disabled and cannot be operated onto.
        case disabled
        /// The account is enabled and ready to operate.
        case enabled
        /// The account is temporary disabled.
        case suspended
    }
    
    /// Account balances.
    public struct Balance {
        /// Balance of funds in the account.
        public let value: Decimal64
        /// Minimum deposit amount required for margins.
        public let deposit: Decimal64
        /// Profit & Loss amount.
        public let profitLoss: Decimal64
        /// Amount available for trading.
        public let available: Decimal64
    }
    
    /// Account preferences.
    public struct Preferences {
        /// Whether the user wants to be allowed to define trailing stop rules for his trade operations.
        ///
        /// A trailing stop is a type of stop order that moves automatically when the market moves in your favour, locking in gains while your position is open.
        public let trailingStops: Bool
    }
}

// MARK: -

extension API.Account: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.id = try container.decode(IG.Account.Identifier.self, forKey: .identifier)
        self.name = try container.decode(String.self, forKey: .name)
        self.alias = try container.decodeIfPresent(String.self, forKey: .alias)
        self.status = try container.decode(Status.self, forKey: .status)
        self.isDefault = try container.decode(Bool.self, forKey: .preferred)
        self.currency = try container.decode(Currency.Code.self, forKey: .currency)
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
        case status, preferred, currency
        case transfersIn = "canTransferFrom"
        case transfersOut = "canTransferTo"
        case type = "accountType"
        case balance
    }
}

extension API.Account.Kind: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "CFD": self = .cfd
        case "PHYSICAL": self = .physical
        case "SPREADBET": self = .spreadBet
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid account type '\(value)'.")
        }
    }
}

extension API.Account.Status: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "DISABLED": self = .disabled
        case "ENABLED": self = .enabled
        case "SUSPENDED_FROM_DEALING": self = .suspended
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid account status '\(value)'.")
        }
    }
}

extension API.Account.Balance: Decodable {
    private enum CodingKeys: String, CodingKey {
        case value = "balance"
        case deposit, profitLoss, available
    }
}

extension API.Account.Preferences: Decodable {
    private enum CodingKeys: String, CodingKey {
        case trailingStops = "trailingStopsEnabled"
    }
}
