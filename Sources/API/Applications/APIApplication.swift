import ReactiveSwift
import Foundation

extension API {
    /// Returns a list of client-owned applications.
    public func applications() -> SignalProducer<[API.Response.Application],API.Error> {
        return SignalProducer(api: self)
            .request(.get, "operations/application", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
    }
    
    /// Alters the details of a given user application.
    /// - parameter apiKey: The API key of the application that will be modified. If `nil`, the application being modified is the one that the API instance has credentials for.
    /// - parameter status: The status to apply to the receiving application.
    /// - parameter accountAllowance: `overall`: Per account request per minute allowance. `trading`: Per account trading request per minute allowance.
    public func updateApplication(apiKey: String? = nil, status: API.Application.Status? = nil, accountAllowance: (overall: Int?, trading: Int?) = (nil, nil)) -> SignalProducer<API.Response.Application,API.Error> {
        return SignalProducer(api: self) { (api) -> API.Request.Application.Update in
                let apiKey = try (apiKey ?? api.credentials().apiKey)
                return try .init(apiKey: apiKey, status: status, overallAccountAllowance: accountAllowance.overall, tradingAccountAllowance: accountAllowance.trading)
            }.request(.put, "operations/application", version: 1, credentials: true, body: { (_,payload) in
                let data = try API.Codecs.jsonEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
    }
}

// MARK: -

extension API.Request {
    /// Client Application.
    fileprivate enum Application {
        /// Let the user updates one parameter of its application.
        fileprivate struct Update: Encodable {
            /// API key to be added to the request.
            let apiKey: String
            /// Desired application status.
            let status: API.Application.Status?
            /// Per account request per minute allowance.
            let overallAccountAllowance: Int?
            /// Per account trading request per minute allowance.
            let tradingAccountAllowance: Int?
            
            /// Designated initializer. It checks that at least one parameter is set.
            init(apiKey: String, status: API.Application.Status? = nil, overallAccountAllowance: Int? = nil, tradingAccountAllowance: Int? = nil) throws {
                guard (status != nil) || (overallAccountAllowance != nil) || (tradingAccountAllowance != nil) else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Applicaion modifications failed! At least one parameter needs to be set when setting an application.")
                }
                self.apiKey = apiKey
                self.status = status
                self.overallAccountAllowance = overallAccountAllowance
                self.tradingAccountAllowance = tradingAccountAllowance
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(self.apiKey, forKey: .apiKey)
                try container.encodeIfPresent(self.status, forKey: .status)
                try container.encodeIfPresent(self.overallAccountAllowance, forKey: .overallAccountAllowance)
                try container.encodeIfPresent(self.tradingAccountAllowance, forKey: .tradingAccountAllowance)
            }
            
            private enum CodingKeys: String, CodingKey {
                case apiKey
                case status
                case overallAccountAllowance = "allowanceAccountOverall"
                case tradingAccountAllowance = "allowanceAccountTrading"
            }
        }
    }
}

// MARK: -

extension API.Response {
    /// Client application.
    public struct Application: Decodable {
        /// Application name given by the developer.
        public let name: String
        /// Application API key identifying the application and the developer.
        public let apiKey: String
        ///  Application status.
        public let status: API.Application.Status
        /// Application creation date (referencing UTC dates, although no time data is stored).
        public let creationDate: Date
        /// What the platform allows the application or account to do (e.g. requests per minute).
        public let allowance: Allowance
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.apiKey = try container.decode(String.self, forKey: .apiKey)
            self.status = try container.decode(API.Application.Status.self, forKey: .status)
            self.creationDate = try container.decode(Date.self, forKey: .creationDate, with: API.DateFormatter.humanReadableNoTime)
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

extension API.Response.Application {
    /// The platform allowance to the application's and account's allowances (e.g. requests per minute).
    public struct Allowance: Decodable {
        /// Boolean indicating if access to equity prices is permitted.
        public let equities: Bool
        /// Boolean indicating if quote orders are permitted.
        public let quoteOrders: Bool
        /// Requests limits and allowances.
        public let requests: Requests
        /// Limits for the lightStreamer connections.
        public let lightStreamer: LightStreamer
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
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

extension API.Response.Application.Allowance {
    /// Limits and allowances for lightstreamer connections.
    public struct LightStreamer: Decodable {
        /// Concurrent subscriptioon limit per lightstreamer connection.
        public let concurrentSubscriptionsLimit: Int
    }
    
    /// The requests (per minute) that the application or account can perform.
    public struct Requests: Decodable {
        /// Overal request per minute allowance.
        public let application: Int
        /// Account related requests per minute allowance.
        public let account: Account
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.application = try container.decode(Int.self, forKey: .application)
            self.account = try Account(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case application = "allowanceApplicationOverall"
        }
    }
}

extension API.Response.Application.Allowance.Requests {
    // Limit and allowances for the targeted account.
    public struct Account: Decodable {
        /// Per account request per minute allowance.
        public let overall: Int
        /// Per account trading request per minute allowance.
        public let trading: Int
        /// Historical price data data points per minute allowance.
        public let historicalData: Int
        
        private enum CodingKeys: String, CodingKey {
            case overall = "allowanceAccountOverall"
            case trading = "allowanceAccountTrading"
            case historicalData = "allowanceAccountHistoricalData"
        }
    }
}
