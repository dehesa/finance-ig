import ReactiveSwift
import Foundation

extension API {
    /// Returns a list of client-owned applications.
    public func applications() -> SignalProducer<[API.Response.Application],API.Error> {
        return self.makeRequest(.get, "operations/application", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
    }
    
    /// Alters the details of a given user application.
    /// - parameter status: Application status.
    /// - parameter accountAllowance: `overall` Per account request per minute allowance. `trading`: Per account trading request per minute allowance.
    public func updateApplication(status: API.Application.Status? = nil, accountAllowance: (overall: Int?, trading: Int?) = (nil, nil)) -> SignalProducer<API.Response.Application,API.Error> {
        return self.makeRequest(.put, "operations/application", version: 1, credentials: true, body: { [weak weakAPI = self] in
                let creds = try weakAPI?.credentials()
                guard let apiKey = creds?.apiKey else {
                    throw API.Error.invalidCredentials(creds, message: "The API key couldn't be retrieved")
                }
                let body = try API.Request.Application.Update(apiKey: apiKey, status: status, overallAccountAllowance: accountAllowance.overall, tradingAccountAllowance: accountAllowance.trading)
                return (.json, try API.Codecs.jsonEncoder().encode(body))
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
    }
}

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

extension API.Response {
    /// Client application.
    public struct Application: Decodable {
        /// Application name given by the developer.
        public let name: String
        /// Application API key identifying the application and the developer.
        public let apiKey: String
        ///  Application status.
        public let status: API.Application.Status
        /// Application creation date.
        public let creationDate: Date
        /// What the platform allows the application or account to do (e.g. requests per minute).
        public let allowance: Allowance
        
        public init(from decoder: Decoder) throws {
            typealias Allow = API.Response.Application.Allowance
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.name = try container.decode(String.self, forKey: .name)
            self.apiKey = try container.decode(String.self, forKey: .apiKey)
            self.status = try container.decode(API.Application.Status.self, forKey: .status)
            self.creationDate = try container.decode(Date.self, forKey: .creationDate, with: API.DateFormatter.humanReadableNoTime)
            
            let overall = try container.decode(Int.self, forKey: .accountOverallAllowance)
            let trading = try container.decode(Int.self, forKey: .accountTradingAllowance)
            let historicalData = try container.decode(Int.self, forKey: .accountHistoricalDataAllowance)
            let account = Allow.Requests.Account(overall: overall, trading: trading, historicalData: historicalData)
            
            let application = try container.decode(Int.self, forKey: .applicationOverallAllowance)
            let requests = Allow.Requests(application: application, account: account)
            
            let concurrentLimit = try container.decode(Int.self, forKey: .concurrentSubscriptionLimit)
            let lightStreamer = Allow.LightStreamer(concurrentSubscription: concurrentLimit)
            
            let equitiesEnabled = try container.decode(Bool.self, forKey: .equitiesAllowance)
            let quoteOrdersEnabled = try container.decode(Bool.self, forKey: .quoteOrdersAllowance)
            self.allowance = Allow(equities: equitiesEnabled, quoteOrders: quoteOrdersEnabled, requests: requests, lightStreamer: lightStreamer)
        }
        
        private enum CodingKeys: String, CodingKey {
            case name
            case apiKey
            case status
            case applicationOverallAllowance = "allowanceApplicationOverall"
            case accountTradingAllowance = "allowanceAccountTrading"
            case accountOverallAllowance = "allowanceAccountOverall"
            case accountHistoricalDataAllowance = "allowanceAccountHistoricalData"
            case concurrentSubscriptionLimit = "concurrentSubscriptionsLimit"
            case equitiesAllowance = "allowEquities"
            case quoteOrdersAllowance = "allowQuoteOrders"
            case creationDate = "createdDate"
        }
    }
}

extension API.Response.Application {
    /// The platform allowance to the application's and account's allowances (e.g. requests per minute).
    public struct Allowance {
        /// Boolean indicating if access to equity prices is permitted.
        public let equities: Bool
        /// Boolean indicating if quote orders are permitted.
        public let quoteOrders: Bool
        /// Requests limits and allowances.
        public let requests: Requests
        /// Limits for the lightStreamer connections.
        public let lightStreamer: LightStreamer
        
        /// Designated initializer for all allowances.
        fileprivate init(equities: Bool, quoteOrders: Bool, requests: Requests, lightStreamer: LightStreamer) {
            self.equities = equities
            self.quoteOrders = quoteOrders
            self.requests = requests
            self.lightStreamer = lightStreamer
        }
        
        /// The requests (per minute) that the application or account can perform.
        public struct Requests {
            /// Overal request per minute allowance.
            public let application: Int
            /// Account related requests per minute allowance.
            public let account: Account
            
            /// Designated initializer for the request-per-minutes allowance.
            fileprivate init(application: Int, account: Account) {
                self.application = application
                self.account = account
            }
            
            // Limit and allowances for the targeted account.
            public struct Account {
                /// Per account request per minute allowance.
                public let overall: Int
                /// Per account trading request per minute allowance.
                public let trading: Int
                /// Historical price data data points per minute allowance.
                public let historicalData: Int
                
                /// Designated initializer for account requests-per-minute allowances.
                fileprivate init(overall: Int, trading: Int, historicalData: Int) {
                    self.trading = trading
                    self.overall = overall
                    self.historicalData = historicalData
                }
            }
        }
        
        /// Limits and allowances for lightstreamer connections.
        public struct LightStreamer {
            /// Concurrent subscriptioon limit per lightstreamer connection.
            public let concurrentSubscriptionLimit: Int
            
            /// Designated initializer for lightStreamer connections.
            fileprivate init(concurrentSubscription: Int) {
                self.concurrentSubscriptionLimit = concurrentSubscription
            }
        }
    }
}
