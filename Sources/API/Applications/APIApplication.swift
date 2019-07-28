import ReactiveSwift
import Foundation

extension API.Request.Applications {
    
    // MARK: GET /operations/application
    
    /// Returns a list of client-owned applications.
    public func getAll() -> SignalProducer<[API.Application],API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "operations/application", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }

    // MARK: PUT /operations/application

    /// Alters the details of a given user application.
    /// - parameter apiKey: The API key of the application that will be modified. If `nil`, the application being modified is the one that the API instance has credentials for.
    /// - parameter status: The status to apply to the receiving application.
    /// - parameter accountAllowance: `overall`: Per account request per minute allowance. `trading`: Per account trading request per minute allowance.
    public func update(apiKey: String? = nil, status: API.Application.Status, accountAllowance: (overall: UInt, trading: UInt)) -> SignalProducer<API.Application,API.Error> {
        return SignalProducer(api: self.api) { (api) -> Self.PayloadUpdate in
                let apiKey = try api.session.credentials?.apiKey ?! API.Error.invalidCredentials(nil, message: "The API key couldn't be found")
                return .init(apiKey: apiKey, status: status, overallAccountAllowance: accountAllowance.overall, tradingAccountAllowance: accountAllowance.trading)
            }.request(.put, "operations/application", version: 1, credentials: true, body: { (_,payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to API applications.
    public struct Applications {
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

extension API.Request.Applications {
    /// Let the user updates one parameter of its application.
    private struct PayloadUpdate: Encodable {
        /// API key to be added to the request.
        let apiKey: String
        /// Desired application status.
        let status: API.Application.Status
        /// Per account request per minute allowance.
        let overallAccountAllowance: UInt
        /// Per account trading request per minute allowance.
        let tradingAccountAllowance: UInt
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Self.CodingKeys.self)
            try container.encode(self.apiKey, forKey: .apiKey)
            try container.encodeIfPresent(self.status, forKey: .status)
            try container.encodeIfPresent(self.overallAccountAllowance, forKey: .overallAccountAllowance)
            try container.encodeIfPresent(self.tradingAccountAllowance, forKey: .tradingAccountAllowance)
        }
        
        private enum CodingKeys: String, CodingKey {
            case apiKey, status
            case overallAccountAllowance = "allowanceAccountOverall"
            case tradingAccountAllowance = "allowanceAccountTrading"
        }
    }
}

// MARK: Response Entities

extension API {
    /// Client application.
    public struct Application: Decodable {
        /// Application name given by the developer.
        public let name: String
        /// Application API key identifying the application and the developer.
        public let apiKey: String
        ///  Application status.
        public let status: Self.Status
        /// Application creation date (referencing UTC dates, although no time data is stored).
        public let creationDate: Date
        /// What the platform allows the application or account to do (e.g. requests per minute).
        public let allowance: Self.Allowance
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.apiKey = try container.decode(String.self, forKey: .apiKey)
            self.status = try container.decode(API.Application.Status.self, forKey: .status)
            self.creationDate = try container.decode(Date.self, forKey: .creationDate, with: API.TimeFormatter.yearMonthDay)
            self.allowance = try Allowance(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case name
            case apiKey
            case status
            case creationDate = "createdDate"
        }
    }
}

extension API.Application {
    /// Application status in the platform.
    public enum Status: String, Codable {
        /// The application is enabled and thus ready to receive/send data.
        case enabled = "ENABLED"
        /// The application has been disabled by the developer.
        case disabled = "DISABLED"
        /// The application has been revoked by the admins.
        case revoked = "REVOKED"
    }
}

extension API.Application {
    /// The platform allowance to the application's and account's allowances (e.g. requests per minute).
    public struct Allowance: Decodable {
        /// Boolean indicating if access to equity prices is permitted.
        public let equities: Bool
        /// Boolean indicating if quote orders are permitted.
        public let quoteOrders: Bool
        /// Requests limits and allowances.
        public let requests: Self.Requests
        /// Limits for the lightStreamer connections.
        public let lightStreamer: Self.LightStreamer
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.equities = try container.decode(Bool.self, forKey: .equitiesAllowance)
            self.quoteOrders = try container.decode(Bool.self, forKey: .quoteOrdersAllowance)
            self.requests = try Requests(from: decoder)
            self.lightStreamer = try LightStreamer(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case equitiesAllowance = "allowEquities"
            case quoteOrdersAllowance = "allowQuoteOrders"
        }
    }
}

extension API.Application.Allowance {
    /// The requests (per minute) that the application or account can perform.
    public struct Requests: Decodable {
        /// Overal application request per minute allowance.
        public let application: UInt
        /// Account related requests per minute allowance.
        public let account: Self.Account
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.application = try container.decode(UInt.self, forKey: .application)
            self.account = try Account(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case application = "allowanceApplicationOverall"
        }
    }
}

extension API.Application.Allowance.Requests {
    // Limit and allowances for the targeted account.
    public struct Account: Decodable {
        /// Per account request per minute allowance.
        public let overall: UInt
        /// Per account trading request per minute allowance.
        public let trading: UInt
        /// Historical price data data points per minute allowance.
        public let historicalData: UInt
        
        private enum CodingKeys: String, CodingKey {
            case overall = "allowanceAccountOverall"
            case trading = "allowanceAccountTrading"
            case historicalData = "allowanceAccountHistoricalData"
        }
    }
}

extension API.Application.Allowance {
    /// Limits and allowances for lightstreamer connections.
    public struct LightStreamer: Decodable {
        /// Concurrent subscriptioon limit per lightstreamer connection.
        public let concurrentSubscriptionsLimit: UInt
    }
}
