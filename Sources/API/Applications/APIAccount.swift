import ReactiveSwift
import Foundation

extension API.Request.Accounts {
    
    // MARK:  GET /accounts
    
    /// Returns a list of accounts belonging to the logged-in client.
    public func getAll() -> SignalProducer<[API.Account],API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "accounts", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperList) in w.accounts }
    }
    
    // MARK:  GET /accounts/preferences
    
    /// Returns the targeted account preferences.
    public func preferences() -> SignalProducer<API.Account.Preferences,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "accounts/preferences", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }

    // MARK:  PUT /accounts/preferences
    
    /// Updates the account preferences.
    /// - parameter trailingStops: Enable/Disable trailing stops in the current account.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func updatePreferences(trailingStops: Bool) -> SignalProducer<Void,API.Error> {
        return SignalProducer(api: self.api) { (_) -> Self.PayloadPreferences in
                return .init(trailingStopsEnabled: trailingStops)
            }.request(.put, "accounts/preferences", version: 1, credentials: true, body: { (_, payload) in
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json)
            .validate(statusCodes: 200)
            .map { (_) in return }
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to user accounts.
    public struct Accounts {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        fileprivate unowned let api: API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        init(api: API) {
            self.api = api
        }
    }
}

// MARK: Request Entities

extension API.Request.Accounts {
    private struct PayloadPreferences: Encodable {
        let trailingStopsEnabled: Bool
    }
}

// MARK: Response Entities

extension API.Request.Accounts {
    private struct WrapperList: Decodable {
        let accounts: [API.Account]
    }
}

extension API {
    /// Client account.
    public struct Account: Decodable {
        /// Account identifier.
        public let identifier: IG.Account.Identifier
        /// Account name.
        public let name: String
        /// Account alias.
        public let alias: String?
        /// Account type
        public let type: Self.Kind
        /// Account status
        public let status: Self.Status
        /// Default/Preferred login account.
        public let isDefault: Bool
        /// Account currency.
        public let currency: Currency.Code
        /// Permission of money transfers in and out of the account.
        public let transfersAllowed: (`in`: Bool, out: Bool)
        /// Account balance.
        public let balance: Self.Balance
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.identifier = try container.decode(IG.Account.Identifier.self, forKey: .identifier)
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
        
        private enum CodingKeys: String, CodingKey {
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
