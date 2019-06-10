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
    /// - todo: validate `dealId` and `FIQL` on SignalProducer(api: self, validating: {})
    public func activity(from: Date, to: Date? = nil, detailed: Bool, filterBy: (dealId: String?, FIQL: String?) = (nil, nil), pageSize: UInt = API.Request.Activity.PageSize.default) -> SignalProducer<[API.Response.Activity],API.Error> {
        var dateFormatter: Foundation.DateFormatter! = nil
        
        return SignalProducer(api: self) { (api) -> Foundation.DateFormatter in
                let formatter = API.DateFormatter.deepCopy(API.DateFormatter.iso8601NoTimezone)
                formatter.timeZone = api.timeZone
                dateFormatter = formatter
                return formatter
            }.request(.get, "history/activity", version: 3, credentials: true, queries: { (api,formatter) in
                var queries = [URLQueryItem(name: "from", value: formatter.string(from: from))]
                
                if let to = to {
                    queries.append(URLQueryItem(name: "to", value: formatter.string(from: to)))
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
                
                return queries
            }).paginate(request: { (api, initialRequest, previous) in
                guard let previous = previous else {
                    return initialRequest
                }
                
                guard let nextURL = previous.meta.nextURL(rootURL: api.rootURL) else {
                    return nil
                }
                
                var nextRequest = initialRequest
                nextRequest.url = nextURL
                return nextRequest
            }, endpoint: { (producer) -> SignalProducer<(API.Response.PagedActivities.Metadata.Page,[API.Response.Activity]),API.Error> in
                return producer.send(expecting: .json)
                    .validateLadenData(statusCodes: [200])
                    .decodeJSON { (request, responseHeader) -> JSONDecoder in
                        let result = API.Codecs.jsonDecoder(request: request, responseHeader: responseHeader)
                        result.userInfo[.dateFormatter] = dateFormatter!
                        return result
                    }.map { (response: API.Response.PagedActivities) in
                        (response.metadata.page, response.activities)
                    }
            })
    }
}

// MARK: -

extension API.Request {
    /// Request constants when asking the platform for trading activities.
    public enum Activity {
        /// Variables related to the paging responses.
        public enum PageSize {
            /// The minimum amount of pages that can be asked for.
            public static var minimum: UInt { return 10 }
            /// The default amount of transactions received in a page.
            public static var `default`: UInt { return 50 }
            /// The maximum amount of pages that can be asked for.
            public static var maximum: UInt { return 500 }
        }
    }
}

// MARK: -

extension API.Response {
    /// Single page of activities request.
    fileprivate struct PagedActivities: Decodable {
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
    fileprivate struct Page: Decodable {
        /// The number of resources/answers delivered in the response.
        let size: Int
        /// The relative url to hit next for getting the following page.
        let nextRelativeURL: URL?
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        /// The absolute `next` URL.
        /// - parameter rootURL: The URL where the the relative URL will be appended to. It shall not have query iems.
        func nextURL(rootURL: URL) -> URL? {
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
        /// The date is relative to the timezone of the account.
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
            
            guard let formatter = decoder.userInfo[.dateFormatter] as? Foundation.DateFormatter else {
                throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "The date formatter supposed to be passed as user info couldn't be found.")
            }
            
            self.date = try container.decode(Date.self, forKey: .date, with: formatter)
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
        /// Transient deal reference for an unconfirmed trade.
        public let dealReference : String?
        /// Deal affected by an activity.
        public let actions: [Action]
        /// A financial market, which may refer to an underlying financial market, or the market being offered in terms of an IG instrument. IG instruments are organised in the form a navigable market hierarchy.
        public let marketName: String
        /// The currency denomination (e.g. `GBP`).
        public let currency: String
        /// Deal direction.
        public let direction: API.Position.Direction
        /// Deal size.
        public let size: Double
        /// Good till date.
        public let goodTillDate: Date?
        /// Instrument price at which the activity has been "commited"
        public let level: Double?
        /// Limit level and distance (from deal price).
        public let limit: Limit?
        /// Stop level and distance (from deal price).
        public let stop: Stop?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.dealReference = try container.decodeIfPresent(String.self, forKey: .dealReference)
            self.actions = try container.decode([Action].self, forKey: .actions)
            self.marketName = try container.decode(String.self, forKey: .marketName)
            self.currency = try container.decode(String.self, forKey: .currency)
            self.direction = try container.decode(API.Position.Direction.self, forKey: .direction)
            self.size = try container.decode(Double.self, forKey: .size)
            
            if let dateString = try container.decodeIfPresent(String.self, forKey: .goodTillDate), dateString != "GTC" {
                guard let formatter = decoder.userInfo[.dateFormatter] as? Foundation.DateFormatter else {
                    throw DecodingError.dataCorruptedError(forKey: .goodTillDate, in: container, debugDescription: "The date formatter supposed to be passed as user info couldn't be found.")
                }
                self.goodTillDate = try formatter.date(from: dateString) ?! DecodingError.dataCorruptedError(forKey: .goodTillDate, in: container, debugDescription: formatter.parseErrorLine(date: dateString))
            } else {
                self.goodTillDate = nil
            }
            
            self.level = try container.decodeIfPresent(Double.self, forKey: .level)
            
            if let level = try container.decodeIfPresent(Double.self, forKey: .limitLevel),
               let distance = try container.decodeIfPresent(Double.self, forKey: .limitDistance) {
                self.limit = .init(level: level, distance: distance)
            } else {
                self.limit = nil
            }
            
            if let level = try container.decodeIfPresent(Double.self, forKey: .stopLevel),
               let distance = try container.decodeIfPresent(Double.self, forKey: .stopDistance) {
                let guaranteed = try container.decode(Bool.self, forKey: .guaranteedStop)
                let td = try container.decodeIfPresent(Double.self, forKey: .trailingStopDistance)
                let ts = try container.decodeIfPresent(Double.self, forKey: .trailingStep)
                self.stop = .init(level: level, distance: distance, isGuaranteed: guaranteed, trailing: (td, ts))
            } else {
                self.stop = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case actions, currency, dealReference, direction, goodTillDate
            case guaranteedStop, level, limitDistance, limitLevel
            case marketName, size, stopDistance, stopLevel
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
    
    /// Indicates the limit level and the distance from the deal price.
    public struct Limit {
        /// The absolute price level of the limit.
        public let level: Double
        /// The price distance from the deal level.
        public let distance: Double
    }
    
    /// Indicates the limit level and the distance from the deal price.
    public struct Stop {
        /// The absolute price level of the limit.
        public let level: Double
        /// The price distance from the deal level.
        public let distance: Double
        /// A stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade. Please note that guaranteed stops come at the price of an increased spread.
        public let isGuaranteed: Bool
        /// Whether it is a trailing stop or not (`nil`).
        public let trailing: Trailing?
        
        /// Designated initializer.
        fileprivate init(level: Double, distance: Double, isGuaranteed: Bool, trailing: (distance: Double?, step: Double?)) {
            self.level = level
            self.distance = distance
            self.isGuaranteed = isGuaranteed
            if let td = trailing.distance, let ts = trailing.step {
                self.trailing = .init(distance: td, step: ts)
            } else {
                self.trailing = nil
            }
        }
        
        /// A type of stop order that moves automatically when the market moves in your favour, locking in gains while your position is open.
        public struct Trailing {
            /// Trailing stop distance.
            public let distance: Double
            /// Trailing step size.
            public let step: Double
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
