import ReactiveSwift
import Foundation

extension API {
    /// Returns the account's activity history.
    ///
    /// This is a paged-request, which means that the `SignalProducer` will return several value events with an array of activities (as indicated by the `pageSize`).
    /// - parameter from: The start date.
    /// - parameter to: The end date (if `nil` means the end of `from` date).
    /// - parameter detailed: Boolean indicating whether to retrieve additional details about the activity.
    /// - parameter filterBy: The filters that can be applied to the search. FIQL filter supporst operators: `==`, `!=`, `,`, and `;`
    /// - parameter pageSize: The number of activities returned per *page* (or `SignalProducer` value).
    public func activity(from: Date, to: Date? = nil, detailed: Bool, filterBy: (dealId: String?, FIQL: String?) = (nil, nil), pageSize: Int = API.Request.Activity.Page.size) -> SignalProducer<[API.Response.Activity],API.Error> {
        /// Constant for this specific request.
        let request: (method: API.HTTP.Method, version: Int, expectedCodes: [Int]) = (.get, 3, [200])
        /// The type of event expected at the end of this SignalProducer pipeline.
        typealias EventResult = Signal<[API.Response.Activity],API.Error>.Event
        /// Beginning of error message.
        let errorBlurb = "Activity retrieval failed!"
        
        return self.paginatedRequest(request: { (api) in
            let absoluteURL = api.rootURL.appendingPathComponent("history/activity")
            var components = try URLComponents(url: absoluteURL, resolvingAgainstBaseURL: true)
                ?! API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The URL \"\(absoluteURL)\" cannot be transformed into URL components.")
            
            var queries = [URLQueryItem(name: "from", value: API.DateFormatter.iso8601NoTimezone.string(from: from))]
            
            if let to = to {
                queries.append(URLQueryItem(name: "to", value: API.DateFormatter.iso8601NoTimezone.string(from: to)))
            }
            
            if detailed {
                queries.append(URLQueryItem(name: "detailed", value: "true"))
            }
            
            if let dealId = filterBy.dealId {
                queries.append(URLQueryItem(name: "dealId", value: dealId))
            }
            
            if let filter = filterBy.FIQL {
                queries.append(URLQueryItem(name: "filter", value: filter))
            }
            
            if pageSize != API.Request.Activity.Page.size {
                guard pageSize >= 0 else { throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The page size must be a positive integer number.") }
                queries.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
            }
            
            components.queryItems = queries
            
            let url = try components.url ?! API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The URL couldn't be formed")
            return try URLRequest(url: url).set {
                $0.setMethod(request.method)
                $0.addHeaders(version: request.version, credentials: try api.credentials())
            }
        }, expectedStatusCodes: request.expectedCodes) { (api: API, page: API.Response.PagedActivities) -> ([EventResult],URLRequest?) in
            guard !page.activities.isEmpty else {
                return ([.completed], nil)
            }
            
            let value: EventResult = .value(page.activities)
            guard let nextRelativeURL = page.metadata.page.nextRelativeURL else {
                return ([value, .completed], nil)
            }
            
            guard let nextURL = page.metadata.page.nextURL(rootURL: api.rootURL) else {
                return ([value, .failed(.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The next page URL couldn't be formed. Root URL: \(api.rootURL). Relative URL is: \(nextRelativeURL)"))], nil)
            }

            var nextRequest = URLRequest(url: nextURL)
            nextRequest.setMethod(request.method)
            
            do {
                nextRequest.addHeaders(version: request.version, credentials: try api.credentials())
            } catch let error {
                return ([value, .failed(error as! API.Error)], nil)
            }
            
            return ([value], nextRequest)
        }
    }
}

extension API.Request {
    /// Request constants when asking the platform for trading activities.
    public enum Activity {
        /// Variables related to the paging responses.
        public enum Page {
            /// The minimum amount of pages that can be asked for.
            public static var minimum: Int { return 10 }
            /// The default amount of transactions received in a page.
            public static var size: Int { return 50 }
            /// The maximum amount of pages that can be asked for.
            public static var maximum: Int { return 500 }
        }
    }
}

extension API.Response {
    /// Single page of activities request.
    internal struct PagedActivities: Decodable {
        /// Wrapper around the queried activities.
        let activities: [API.Response.Activity]
        /// Metadata information about current request.
        let metadata: Metadata
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        /// Page's extra information.
        struct Metadata: Decodable {
            /// Variables related to the current page.
            let page: Page
            
            /// Do not call! The only way to initialize is through `Decodable`.
            private init?() { fatalError("Unaccessible initializer") }
            
            private enum CodingKeys: String, CodingKey {
                case page = "paging"
            }
        }
    }
}

extension API.Response.PagedActivities.Metadata {
    /// Paging metadata response.
    public struct Page: Decodable {
        /// The number of resources/answers delivered in the response.
        public let size: Int
        /// The relative url to hit next for getting the following page.
        public let nextRelativeURL: URL?
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        /// The absolute `next` URL.
        /// - parameter rootURL: The URL where the the relative URL will be appended to. It shall not have query iems.
        public func nextURL(rootURL: URL) -> URL? {
            guard let url = self.nextRelativeURL,
                  let next = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  var root = URLComponents(url: rootURL, resolvingAgainstBaseURL: true) else {
                return nil
            }
            
            root.path = root.path.appending(next.path)
            root.queryItems = next.queryItems
            return root.url
        }
        
        private enum CodingKeys: String, CodingKey {
            case size
            case nextRelativeURL = "next"
        }
    }
}

extension API.Response {
    /// A trading activity on the given account.
    public struct Activity: Decodable {
        /// The date of the activity item.
        public let date: Date
        /// Deal identifier.
        public let dealId: String
        /// Activity type.
        public let type: Kind
        /// Action status.
        public let status: Status
        /// The channel which triggered the activity.
        public let channel: Channel
        /// Instrument epic identifier.
        public let epic: String
        /// The period of the activity item.
        public let period: API.Expiry
        /// Activity description.
        public let description: String
        /// Activity details.
        public let details: Details?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.date = try container.decode(Date.self, forKey: .date, with: API.DateFormatter.iso8601NoTimezone)
            self.dealId = try container.decode(String.self, forKey: .dealId)
            self.type = try container.decode(Kind.self, forKey: .type)
            self.status = try container.decode(Status.self, forKey: .status)
            self.channel = try container.decode(Channel.self, forKey: .channel)
            self.description = try container.decode(String.self, forKey: .description)
            self.epic = try container.decode(String.self, forKey: .epic)
            self.period = try container.decodeIfPresent(API.Expiry.self, forKey: .period) ?? .none
            self.details = try container.decodeIfPresent(Details.self, forKey: .details)
        }
        
        private enum CodingKeys: String, CodingKey {
            case date, dealId, type, status, channel, epic, period, description, details
        }
    }
}

extension API.Response.Activity {
    /// Activity Type.
    public enum Kind: String, Decodable {
        /// System generated activity.
        case system = "SYSTEM"
        /// Position activity.
        case position = "POSITION"
        /// Working order activity.
        case workingOrder = "WORKING_ORDER"
        /// Amend stop or limit activity.
        case amended = "EDIT_STOP_AND_LIMIT"
    }
    
    /// Activity status.
    public enum Status: String, Decodable {
        /// The activity has been accepted.
        case accepted = "ACCEPTED"
        /// The activity has been rejected.
        case rejected = "REJECTED"
        /// The activity status is unknown.
        case unknown = "UNKNOWN"
    }
    
    /// Trigger channel.
    public enum Channel: String, Decodable {
        /// Activity performed through an outside dealer.
        case dealer = "DEALER"
        /// Activity performed through the mobile app.
        case mobile = "MOBILE"
        /// Activity performed through the financial FIX system.
        case fix = "PUBLIC_FIX_API"
        /// Activity performed through the platform's internal system.
        case system = "SYSTEM"
        /// Activity performed through the platform's website.
        case web = "WEB"
        /// Activity performed through the API.
        case webAPI = "PUBLIC_WEB_API"
    }

    /// Further details of the targeted activity.
    public struct Details: Decodable {
        /// Deal affected by an activity.
        public let actions: [Action]
        /// The currency denomination (e.g. `GBP`).
        public let currency: String
        /// Transient deal reference for an unconfirmed trade.
        public let dealReference : String
        /// Deal direction.
        public let direction: API.Position.Direction
        /// Size.
        public let size: Double
        /// Good till date.
        public let goodTillDate: Date?
        /// A stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade. Please note that guaranteed stops come at the price of an increased spread.
        public let guaranteedStop: Bool
        /// Instrument price.
        public let level: Double
        /// Limit level.
        public let levelLimit: Double
        /// Stop level.
        public let levelStop: Double
        /// Limit distance.
        public let limitDistance: Double
        /// A financial market, which may refer to an underlying financial market, or the market being offered in terms of an IG instrument. IG instruments are organised in the form a navigable market hierarchy.
        public let marketName: String
        /// Stop distance.
        public let stopDistance: Double
        /// Trailing step size.
        public let trailingStep: Bool?
        /// Trailing stop distance.
        public let trailingStopDistance: Bool?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.actions = try container.decode([Action].self, forKey: .actions)
            self.currency = try container.decode(String.self, forKey: .currency)
            self.dealReference = try container.decode(String.self, forKey: .dealReference)
            self.direction = try container.decode(API.Position.Direction.self, forKey: .direction)
            self.goodTillDate = try container.decodeIfPresent(Date.self, forKey: .goodTillDate, with: API.DateFormatter.iso8601NoTimezone)
            self.guaranteedStop = try container.decode(Bool.self, forKey: .guaranteedStop)
            self.level = try container.decode(Double.self, forKey: .level)
            self.limitDistance = try container.decode(Double.self, forKey: .limitDistance)
            self.levelLimit = try container.decode(Double.self, forKey: .levelLimit)
            self.marketName = try container.decode(String.self, forKey: .marketName)
            self.size = try container.decode(Double.self, forKey: .size)
            self.stopDistance = try container.decode(Double.self, forKey: .stopDistance)
            self.levelStop = try container.decode(Double.self, forKey: .levelStop)
            self.trailingStep = try container.decodeIfPresent(Bool.self, forKey: .trailingStep)
            self.trailingStopDistance = try container.decodeIfPresent(Bool.self, forKey: .trailingStopDistance)
        }
        
        private enum CodingKeys: String, CodingKey {
            case actions, currency, dealReference, direction, goodTillDate
            case guaranteedStop, level, limitDistance
            case levelLimit = "limitLevel"
            case marketName, size, stopDistance
            case levelStop = "stopLevel"
            case trailingStep, trailingStopDistance
        }
    }
}

extension API.Response.Activity.Details {
    /// Deal affected by an activity.
    public struct Action: Decodable {
        /// Action type.
        public let type: Kind
        /// Affected deal identifier.
        public let dealId: String
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        private enum CodingKeys: String, CodingKey {
            case type = "actionType"
            case dealId = "affectedDealId"
        }
    }
}

extension API.Response.Activity.Details.Action {
    /// Type of action.
    public enum Kind: String, Decodable {
        case limitOrderOpened = "LIMIT_ORDER_OPENED"
        case limitOrderFilled = "LIMIT_ORDER_FILLED"
        case limitOrderAmended = "LIMIT_ORDER_AMENDED"
        case limitOrderRolled = "LIMIT_ORDER_ROLLED"
        case limitOrderDeleted = "LIMIT_ORDER_DELETED"
        
        case positionOpenend = "POSITION_OPENED"
        case positionRolled = "POSITION_ROLLED"
        case positionPartiallyClosed = "POSITION_PARTIALLY_CLOSED"
        case positionClosed = "POSITION_CLOSED"
        case positionDeleted = "POSITION_DELETED"
        
        case stopLimitAmended = "STOP_LIMIT_AMENDED"
        
        case stopOrderOpened = "STOP_ORDER_OPENED"
        case stopOrderFilled = "STOP_ORDER_FILLED"
        case stopOrderAmended = "STOP_ORDER_AMENDED"
        case stopOrderRolled = "STOP_ORDER_ROLLED"
        case stopOrderDeleted = "STOP_ORDER_DELETED"
        
        case unknown = "UNKNOWN"
        case workingOrderDeleted = "WORKING_ORDER_DELETED"
    }
}
