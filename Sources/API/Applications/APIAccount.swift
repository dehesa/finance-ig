import ReactiveSwift
import Foundation

extension API.Request {
    /// Contains all functionality related to user accounts.
    public struct Accounts {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        fileprivate unowned let api: API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the session endpoints.
        init(api: API) {
            self.api = api
        }
    }
}

// MARK: - GET /accounts

extension API {
    /// Client account.
    public struct Account: Decodable {
        /// Account identifier.
        public let identifier: String
        /// Account name.
        public let name: String
        /// Account alias.
        public let alias: String?
        /// Account status
        public let status: Status
        /// Default login account.
        public let preferred: Bool
        /// Account currency.
        public let currency: String
        /// Permission of money transfers in and out of the account.
        public let transfersAllowed: (`in`: Bool, out: Bool)
        /// Account type
        public let type: Kind
        /// Account balance.
        public let balance: Balance
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.identifier = try container.decode(String.self, forKey: .identifier)
            self.name = try container.decode(String.self, forKey: .name)
            self.alias = try container.decodeIfPresent(String.self, forKey: .alias)
            self.status = try container.decode(Status.self, forKey: .status)
            self.preferred = try container.decode(Bool.self, forKey: .preferred)
            self.currency = try container.decode(String.self, forKey: .currency)
            let transferIn = try container.decode(Bool.self, forKey: .transfersIn)
            let transferOut = try container.decode(Bool.self, forKey: .transfersOut)
            self.transfersAllowed = (transferIn, transferOut)
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
        public let value: Double
        /// Minimum deposit amount required for margins.
        public let deposit: Double
        /// Profit & Loss amount.
        public let profitLoss: Double
        /// Amount available for trading.
        public let available: Double
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        private enum CodingKeys: String, CodingKey {
            case value = "balance"
            case deposit
            case profitLoss
            case available
        }
    }
}

extension API.Request.Accounts {
    /// Returns a list of accounts belonging to the logged-in client.
    public func getAll() -> SignalProducer<[API.Account],API.Error> {
        struct Wrapper: Decodable {
            let accounts: [API.Account]
        }
        
        return SignalProducer(api: self.api)
            .request(.get, "accounts", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: Wrapper) in w.accounts }
    }
}

// MARK: - GET /accounts/preferences

extension API.Account {
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

extension API.Request.Accounts {
    /// Returns the targeted account preferences.
    public func preferences() -> SignalProducer<API.Account.Preferences,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "accounts/preferences", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
    }
}

// MARK: - PUT /accounts/preferences

extension API.Request.Accounts {
    /// Updates the account preferences.
    /// - parameter trailingStops: Enable/Disable trailing stops in the current account.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func updatePreferences(trailingStops: Bool) -> SignalProducer<Void,API.Error> {
        struct Payload: Encodable {
            let trailingStopsEnabled: Bool
        }
        
        return SignalProducer(api: self.api) { (_) -> Payload in
                return .init(trailingStopsEnabled: trailingStops)
            }.request(.put, "accounts/preferences", version: 1, credentials: true, body: { (_, payload) in
                return (.json, try API.Codecs.jsonEncoder().encode(payload))
            }).send(expecting: .json)
            .validate(statusCodes: [200])
            .map { (_) in return }
    }
}
