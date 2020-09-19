import Foundation

extension API {
    /// Client application.
    public struct Application {
        /// Application creation date (referencing UTC dates, although no time data is stored).
        public let date: Date
        /// Application API key identifying the application and the developer.
        public let key: API.Key
        /// Application name given by the developer.
        public let name: String
        ///  Application status.
        public let status: Self.Status
        /// What the platform allows the application or account to do (e.g. requests per minute).
        public let permission: Self.Permission
        /// The limits at which the receiving application is constrained to.
        public let allowance: Self.Allowance
    }
}

extension API.Application {
    /// Application status in the platform.
    public enum Status: Hashable {
        /// The application is enabled and thus ready to receive/send data.
        case enabled
        /// The application has been disabled by the developer.
        case disabled
        /// The application has been revoked by the admins.
        case revoked
    }
}

extension API.Application {
    /// The platform allowance to the application's and account's allowances (e.g. requests per minute).
    public struct Permission: Equatable {
        /// Boolean indicating if access to equity prices is permitted.
        public let accessToEquityPrices: Bool
        /// Boolean indicating if quote orders are permitted.
        public let areQuoteOrdersAllowed: Bool
    }
}

extension API.Application {
    /// The limits constraining an API application.
    public struct Allowance: Equatable {
        /// Overal application request per minute allowance.
        public let overallRequests: Int
        /// Account related requests per minute allowance.
        public let account: Self.Account
        /// Concurrent subscriptioon limit per lightstreamer connection.
        public let subscriptionsLimit: Int
    }
}

extension API.Application.Allowance {
    /// Limit and allowances for the targeted account.
    public struct Account: Equatable {
        /// Per account request per minute allowance.
        public let overallRequests: Int
        /// Per account trading request per minute allowance.
        public let tradingRequests: Int
        /// Historical price data data points per minute allowance.
        public let historicalDataRequests: Int
    }
}

// MARK: -

extension API.Application: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        self.date = try container.decode(Date.self, forKey: .creationDate, with: .date)
        self.key = try container.decode(API.Key.self, forKey: .key)
        self.name = try container.decode(String.self, forKey: .name)
        self.status = try container.decode(API.Application.Status.self, forKey: .status)
        self.permission = try Self.Permission(from: decoder)
        self.allowance = try Self.Allowance(from: decoder)
    }
    
    internal enum CodingKeys: String, CodingKey {
        case name, key = "apiKey"
        case status, creationDate = "createdDate"
    }
}

extension API.Application.Status: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case _Values.enabled: self = .enabled
        case _Values.disabled: self = .disabled
        case _Values.revoked: self = .revoked
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid application status '\(value)'.")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .enabled: try container.encode(_Values.enabled)
        case .disabled: try container.encode(_Values.disabled)
        case .revoked: try container.encode(_Values.revoked)
        }
    }
    
    private enum _Values {
        static var enabled: String { "ENABLED" }
        static var disabled: String { "DISABLED" }
        static var revoked: String { "REVOKED" }
    }
}

extension API.Application.Permission: Decodable {
    private enum CodingKeys: String, CodingKey {
        case accessToEquityPrices = "allowEquities"
        case areQuoteOrdersAllowed = "allowQuoteOrders"
    }
}

extension API.Application.Allowance: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.overallRequests = try container.decode(Int.self, forKey: .requests)
        self.subscriptionsLimit = try container.decode(Int.self, forKey: .subscriptions)
        self.account = try .init(from: decoder)
    }
    
    private enum _Keys: String, CodingKey {
        case requests = "allowanceApplicationOverall"
        case subscriptions = "concurrentSubscriptionsLimit"
    }
}

extension API.Application.Allowance.Account: Decodable {
    private enum CodingKeys: String, CodingKey {
        case overallRequests = "allowanceAccountOverall"
        case tradingRequests = "allowanceAccountTrading"
        case historicalDataRequests = "allowanceAccountHistoricalData"
    }
}
