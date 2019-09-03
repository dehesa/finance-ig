import ReactiveSwift
import Foundation

extension IG.API.Request.History {
    
    // MARK: GET /history/activity
    
    /// Returns the account's activity history.
    ///
    /// **This is a paginated-request**, which means that the `SignalProducer` will return several value events with an array of activities (as indicated by the `pageSize`).
    /// - attention: The results are returned from newest to oldest.
    /// - parameter from: The start date.
    /// - parameter to: The end date (if `nil` means the end of `from` date).
    /// - parameter detailed: Boolean indicating whether to retrieve additional details about the activity.
    /// - parameter filterBy: The filters that can be applied to the search. FIQL filter supporst operators: `==`, `!=`, `,`, and `;`
    /// - parameter pageSize: The number of activities returned per *page* (or `SignalProducer` value).
    /// - todo: validate `dealId` and `FIQL` on SignalProducer(api: self, validating: {})
    public func getActivity(from: Date, to: Date? = nil, detailed: Bool, filterBy: (identifier: IG.Deal.Identifier?, FIQL: String?) = (nil, nil), pageSize: UInt = 50) -> SignalProducer<[IG.API.Activity],IG.API.Error> {
        let dateFormatter: DateFormatter = IG.API.Formatter.iso8601.deepCopy
        
        return SignalProducer(api: self.api) { (api) -> DateFormatter in
                guard let timezone = api.session.credentials?.timezone else {
                    throw IG.API.Error.invalidRequest(IG.API.Error.Message.noCredentials, suggestion: IG.API.Error.Suggestion.logIn)
                }
                dateFormatter.timeZone = timezone
                return dateFormatter
            }.request(.get, "history/activity", version: 3, credentials: true, queries: { (api,formatter) in
                var queries = [URLQueryItem(name: "from", value: formatter.string(from: from))]
                
                if let to = to {
                    queries.append(URLQueryItem(name: "to", value: formatter.string(from: to)))
                }
                
                if detailed {
                    queries.append(URLQueryItem(name: "detailed", value: "true"))
                }
                
                if let dealIdentifier = filterBy.identifier {
                    queries.append(URLQueryItem(name: "dealId", value: dealIdentifier.rawValue))
                }
                
                if let filter = filterBy.FIQL {
                    queries.append(URLQueryItem(name: "filter", value: filter))
                }
                
                let size: UInt = (pageSize < 500) ? 500 :
                                 (pageSize > 10)  ? 10  : pageSize
                queries.append(URLQueryItem(name: "pageSize", value: String(size)))
                return queries
            }).paginate(request: { (api, initialRequest, previous) in
                guard let previous = previous else {
                    return initialRequest
                }
                
                guard let next = previous.meta.next else {
                    return nil
                }
                
                guard let queries = URLComponents(string: next)?.queryItems else {
                    let message = #"The paginated request for activities couldn't be processed because there were no "next" queries."#
                    throw IG.API.Error.invalidRequest(message, request: previous.request, suggestion: IG.API.Error.Suggestion.bug)
                }
                
                guard let from = queries.first(where: { $0.name == "from" }),
                      let to = queries.first(where: { $0.name == "to" }) else {
                    let message = #"The paginated request for activies couldn't be processed because the "from" and/or "to" queries couldn't be found."#
                    throw IG.API.Error.invalidRequest(message, request: previous.request, suggestion: IG.API.Error.Suggestion.bug)
                }
                
                var nextRequest = initialRequest
                try nextRequest.addQueries([from, to])
                return nextRequest
            }, endpoint: { (producer) -> SignalProducer<(Self.PagedActivities.Metadata.Page,[IG.API.Activity]),IG.API.Error> in
                return producer.send(expecting: .json)
                    .validateLadenData(statusCodes: 200)
                    .decodeJSON { (_,_) -> JSONDecoder in
                        let decoder = JSONDecoder()
                        decoder.userInfo[IG.API.JSON.DecoderKey.dateFormatter] = dateFormatter
                        return decoder
                    }.map { (response: Self.PagedActivities) in
                        (response.metadata.paging, response.activities)
                    }
            })
    }
}

// MARK: - Supporting Entities

extension IG.API.Request {
    /// Contains all functionality related to a user's activity.
    public struct History {
        /// Pointer to the actual API instance in charge of calling the endpoints.
        internal unowned let api: IG.API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        init(api: IG.API) {
            self.api = api
        }
    }
}

// MARK: Response Entities

extension IG.API.Request.History {
    /// A single page of activity requests.
    private struct PagedActivities: Decodable {
        let activities: [IG.API.Activity]
        let metadata: Metadata
        
        struct Metadata: Decodable {
            let paging: Page
            
            struct Page: Decodable {
                /// The number of resources/answers delivered in the response.
                let size: Int
                /// The relative url to hit next for getting the following page.
                let next: String?
            }
        }
    }
}

extension IG.API {
    /// A trading activity on the given account.
    public struct Activity: Decodable {
        /// The date of the activity item.
        public let date: Date
        /// Activity description.
        public let title: String
        /// Activity type.
        public let type: Self.Kind
        /// Action status.
        public let status: Self.Status
        /// The channel which triggered the activity.
        public let channel: Self.Channel
        /// Deal identifier.
        public let dealIdentifier: IG.Deal.Identifier
        /// Instrument epic identifier.
        public let epic: IG.Market.Epic
        /// The period of the activity item.
        public let expiry: IG.Market.Expiry
        /// Activity details.
        public let details: Self.Details?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            let formatter = try decoder.userInfo[IG.API.JSON.DecoderKey.dateFormatter] as? DateFormatter
                ?! DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "The date formatter supposed to be passed as user info couldn't be found.")
            self.date = try container.decode(Date.self, forKey: .date, with: formatter)
            self.title = try container.decode(String.self, forKey: .title)
            self.type = try container.decode(Self.Kind.self, forKey: .type)
            self.status = try container.decode(Self.Status.self, forKey: .status)
            self.channel = try container.decode(Self.Channel.self, forKey: .channel)
            self.dealIdentifier = try container.decode(IG.Deal.Identifier.self, forKey: .dealIdentifier)
            self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
            self.expiry = try container.decodeIfPresent(IG.Market.Expiry.self, forKey: .expiry) ?? .none
            self.details = try container.decodeIfPresent(Self.Details.self, forKey: .details)
        }
        
        private enum CodingKeys: String, CodingKey {
            case date, title = "description"
            case type, status, channel
            case dealIdentifier = "dealId"
            case epic, expiry = "period"
            case details
        }
    }
}

extension IG.API.Activity {
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
        /// Activity performed through the platform's internal system.
        case system = "SYSTEM"
        /// Activity performed through the platform's website.
        case web = "WEB"
        /// Activity performed through the mobile app.
        case mobile = "MOBILE"
        /// Activity performed through the API.
        case api = "PUBLIC_WEB_API"
        /// Activity performed through an outside dealer.
        case dealer = "DEALER"
        /// Activity performed through the financial FIX system.
        case fix = "PUBLIC_FIX_API"
    }

    /// Further details of the targeted activity.
    public struct Details: Decodable {
        /// Transient deal reference for an unconfirmed trade.
        public let dealReference : IG.Deal.Reference?
        /// Deal affected by an activity.
        public let actions: [IG.API.Activity.Action]
        /// A financial market, which may refer to an underlying financial market, or the market being offered in terms of an IG instrument. IG instruments are organised in the form a navigable market hierarchy.
        public let marketName: String
        /// The currency denomination.
        public let currencyCode: IG.Currency.Code
        /// Deal direction.
        public let direction: IG.Deal.Direction
        /// Deal size.
        public let size: Decimal
        /// Instrument price at which the activity has been "commited"
        public let level: Decimal
        /// Level at which the user is happy to take profit.
        public let limit: IG.Deal.Limit?
        /// Stop for the targeted deal
        public let stop: IG.Deal.Stop?
        /// Working order expiration.
        ///
        /// If the activity doesn't reference a working order, this property will be `nil`.
        public let workingOrderExpiration: IG.API.WorkingOrder.Expiration?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.dealReference = try container.decodeIfPresent(IG.Deal.Reference.self, forKey: .dealReference)
            self.actions = try container.decode([IG.API.Activity.Action].self, forKey: .actions)
            self.marketName = try container.decode(String.self, forKey: .marketName)
            self.currencyCode = try container.decode(IG.Currency.Code.self, forKey: .currencyCode)
            self.direction = try container.decode(IG.Deal.Direction.self, forKey: .direction)
            self.size = try container.decode(Decimal.self, forKey: .size)
            self.level = try container.decode(Decimal.self, forKey: .level)
            self.limit = try container.decodeIfPresent(IG.Deal.Limit.self, forLevelKey: .limitLevel, distanceKey: .limitDistance)
            self.stop = try container.decodeIfPresent(IG.Deal.Stop.self, forLevelKey: .stopLevel, distanceKey: .stopDistance, riskKey: (.isStopGuaranteed, nil), trailingKey: (nil, .stopTrailingDistance, .stopTrailingIncrement))
            self.workingOrderExpiration = try {
                switch try container.decodeIfPresent(String.self, forKey: .expiration) {
                case .none: return nil
                case "GTC": return .tillCancelled
                case let dateString?:
                    guard let formatter = decoder.userInfo[IG.API.JSON.DecoderKey.dateFormatter] as? DateFormatter else {
                        throw DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: "The date formatter supposed to be passed as user info couldn't be found.")
                    }
                    let date = try formatter.date(from: dateString) ?! DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: formatter.parseErrorLine(date: dateString))
                    return .tillDate(date)
                }
            }()
        }
        
        private enum CodingKeys: String, CodingKey {
            case dealReference, actions
            case currencyCode = "currency"
            case direction, marketName, size
            case level, limitLevel, limitDistance
            case stopLevel, stopDistance, isStopGuaranteed = "guaranteedStop"
            case stopTrailingDistance = "trailingStopDistance", stopTrailingIncrement = "trailingStep"
            case expiration = "goodTillDate"
        }
    }
}

extension IG.API.Activity {
    /// Deal affected by an activity.
    public struct Action: Decodable {
        /// Action type.
        public let type: Self.Kind
        /// Affected deal identifier.
        public let dealIdentifier: IG.Deal.Identifier
        
        /// Do not call! The only way to initialize is through `Decodable`.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.dealIdentifier = try container.decode(IG.Deal.Identifier.self, forKey: .dealIdentifier)
            
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "STOP_LIMIT_AMENDED":  self.type = .dealStopLimitAmended
            case "POSITION_OPENED":     self.type = .position(status: .opened)
            case "POSITION_ROLLED":     self.type = .position(status: .rolled)
            case "POSITION_PARTIALLY_CLOSED": self.type = .position(status: .partiallyClosed)
            case "POSITION_CLOSED":     self.type = .position(status: .closed)
            case "POSITION_DELETED":    self.type = .position(status: .deleted)
            case "LIMIT_ORDER_OPENED":  self.type = .workingOrder(status: .opened, type: .limit)
            case "LIMIT_ORDER_FILLED":  self.type = .workingOrder(status: .filled, type: .limit)
            case "LIMIT_ORDER_AMENDED": self.type = .workingOrder(status: .amended, type: .limit)
            case "LIMIT_ORDER_ROLLED":  self.type = .workingOrder(status: .rolled, type: .limit)
            case "LIMIT_ORDER_DELETED": self.type = .workingOrder(status: .deleted, type: .limit)
            case "STOP_ORDER_OPENED":   self.type = .workingOrder(status: .opened, type: .stop)
            case "STOP_ORDER_FILLED":   self.type = .workingOrder(status: .filled, type: .stop)
            case "STOP_ORDER_AMENDED":  self.type = .workingOrder(status: .amended, type: .stop)
            case "STOP_ORDER_ROLLED":   self.type = .workingOrder(status: .rolled, type: .stop)
            case "STOP_ORDER_DELETED":  self.type = .workingOrder(status: .deleted, type: .stop)
            case "WORKING_ORDER_DELETED": self.type = .workingOrder(status: .deleted, type: nil)
            case "UNKNOWN":             self.type = .unknown
            default:
                let description = #"The action type "\#(type)" couldn't be identified."#
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: description)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case type = "actionType"
            case dealIdentifier = "affectedDealId"
        }
        
        /// The action type.
        ///
        /// Refects who is the receiver of the action on what status has been changed to.
        public enum Kind {
            /// The action affects a position and its status has been modified to the one given here.
            case position(status: IG.API.Activity.Action.PositionStatus)
            /// The action affects a working order and its status has been modified to the one given here.
            case workingOrder(status: IG.API.Activity.Action.WorkingOrderStatus, type: IG.API.WorkingOrder.Kind?)
            /// A deal's stop and/or limit has been amended.
            case dealStopLimitAmended
            /// The action is of unknown character.
            case unknown
        }
        
        /// Position's action status.
        public enum PositionStatus {
            case opened
            case rolled
            case partiallyClosed
            case closed
            case deleted
        }
        
        /// Working order's action status.
        public enum WorkingOrderStatus {
            case opened
            case filled
            case amended
            case rolled
            case deleted
        }
    }
}
