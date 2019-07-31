import ReactiveSwift
import Foundation

extension API.Request.Activity {
    
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
    public func get(from: Date, to: Date? = nil, detailed: Bool, filterBy: (dealId: String?, FIQL: String?) = (nil, nil), pageSize: UInt = Self.PageSize.default) -> SignalProducer<[API.Activity],API.Error> {
        let dateFormatter: DateFormatter = API.TimeFormatter.iso8601NoTimezone.deepCopy
        
        return SignalProducer(api: self.api) { (api) -> DateFormatter in
                let timezone = try api.session.credentials?.timezone ?! API.Error.invalidCredentials(nil, message: "No credentials were found; thus, the user's timezone couldn't be inferred.")
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
                
                if let dealId = filterBy.dealId {
                    queries.append(URLQueryItem(name: "dealId", value: dealId))
                }
                
                if let filter = filterBy.FIQL {
                    queries.append(URLQueryItem(name: "filter", value: filter))
                }
                
                let size: UInt = (pageSize < Self.PageSize.minimum) ? Self.PageSize.minimum :
                                 (pageSize > Self.PageSize.maximum) ? Self.PageSize.maximum : pageSize
                queries.append(URLQueryItem(name: "pageSize", value: String(size)))
                return queries
            }).paginate(request: { (api, initialRequest, previous) in
                guard let previous = previous else {
                    return initialRequest
                }
                
                guard let next = previous.meta.next else {
                    return nil
                }
                
                let queries = try URLComponents(string: next)?.queryItems ?! API.Error.invalidRequest(underlyingError: nil, message: "The paginated request for activities couldn't be processed because there were no \"next\" queries.")
                
                guard let from = queries.first(where: { $0.name == "from" }),
                      let to = queries.first(where: { $0.name == "to" }) else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The paginated request for activies couldn't be processed because the \"from\" and/or \"to\" queries couldn't be found.")
                }
                
                var nextRequest = initialRequest
                try nextRequest.addQueries([from, to])
                return nextRequest
            }, endpoint: { (producer) -> SignalProducer<(Self.PagedActivities.Metadata.Page,[API.Activity]),API.Error> in
                return producer.send(expecting: .json)
                    .validateLadenData(statusCodes: 200)
                    .decodeJSON { (_,_) -> JSONDecoder in
                        let decoder = JSONDecoder()
                        decoder.userInfo[API.JSON.DecoderKey.dateFormatter] = dateFormatter
                        return decoder
                    }.map { (response: Self.PagedActivities) in
                        (response.metadata.paging, response.activities)
                    }
            })
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to a user's activity.
    public struct Activity {
        /// Pointer to the actual API instance in charge of calling the endpoints.
        fileprivate unowned let api: API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        init(api: API) {
            self.api = api
        }
    }
}

// MARK: Request Entities

extension API.Request.Activity {
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

// MARK: Response Entities

extension API.Request.Activity {
    /// A single page of activity requests.
    private struct PagedActivities: Decodable {
        let activities: [API.Activity]
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

extension API {
    /// A trading activity on the given account.
    public struct Activity: Decodable {
        /// Deal identifier.
        public let dealIdentifier: API.Deal.Identifier
        /// Activity type.
        public let type: Self.Kind
        /// Action status.
        public let status: Self.Status
        /// The date of the activity item.
        public let date: Date
        /// The channel which triggered the activity.
        public let channel: Self.Channel
        /// Instrument epic identifier.
        public let epic: Epic
        /// The period of the activity item.
        public let expiry: API.Instrument.Expiry
        /// Activity description.
        public let title: String
        /// Activity details.
        public let details: Self.Details?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            let formatter = try decoder.userInfo[API.JSON.DecoderKey.dateFormatter] as? DateFormatter
                ?! DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "The date formatter supposed to be passed as user info couldn't be found.")
            self.date = try container.decode(Date.self, forKey: .date, with: formatter)
            self.dealIdentifier = try container.decode(API.Deal.Identifier.self, forKey: .dealId)
            self.type = try container.decode(Self.Kind.self, forKey: .type)
            self.status = try container.decode(Self.Status.self, forKey: .status)
            self.channel = try container.decode(Self.Channel.self, forKey: .channel)
            self.title = try container.decode(String.self, forKey: .title)
            self.epic = try container.decode(Epic.self, forKey: .epic)
            self.expiry = try container.decodeIfPresent(API.Instrument.Expiry.self, forKey: .expiry) ?? .none
            self.details = try container.decodeIfPresent(Self.Details.self, forKey: .details)
        }
        
        private enum CodingKeys: String, CodingKey {
            case dealId, type, status, date, channel
            case epic, expiry = "period"
            case title = "description", details
        }
    }
}

extension API.Activity {
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
        public let dealReference : API.Deal.Reference?
        /// Deal affected by an activity.
        public let actions: [Self.Action]
        /// A financial market, which may refer to an underlying financial market, or the market being offered in terms of an IG instrument. IG instruments are organised in the form a navigable market hierarchy.
        public let marketName: String
        /// The currency denomination (e.g. `GBP`).
        public let currency: Currency.Code
        /// Deal direction.
        public let direction: API.Deal.Direction
        /// Deal size.
        public let size: Decimal
        /// Instrument price at which the activity has been "commited"
        public let level: Decimal
        /// Level at which the user is happy to take profit.
        public let limit: API.Deal.Limit?
        /// Stop for the targeted deal
        public let stop: API.Deal.Stop?
        /// Working order expiration.
        ///
        /// If the activity doesn't reference a working order, this property will be `nil`.
        public let expiration: API.WorkingOrder.Expiration?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.dealReference = try container.decodeIfPresent(API.Deal.Reference.self, forKey: .dealReference)
            self.actions = try container.decode([Action].self, forKey: .actions)
            self.marketName = try container.decode(String.self, forKey: .marketName)
            self.currency = try container.decode(Currency.Code.self, forKey: .currency)
            self.direction = try container.decode(API.Deal.Direction.self, forKey: .direction)
            self.size = try container.decode(Decimal.self, forKey: .size)
            self.level = try container.decode(Decimal.self, forKey: .level)
            // Figure out limit.
            let limitLevel = try container.decodeIfPresent(Decimal.self, forKey: .limitLevel)
            let limitDistance = try container.decodeIfPresent(Decimal.self, forKey: .limitDistance)
            switch (limitLevel, limitDistance) {
            case (.none, .none):
                self.limit = nil
            case (.none, let distance?):
                self.limit = .distance(distance)
            case (let level?,_):
                self.limit = .position(level: level)
            }
            // Figure out stop.
            let stop: API.Deal.Stop.Kind?
            let stopLevel = try container.decodeIfPresent(Decimal.self, forKey: .stopLevel)
            let stopDistance = try container.decodeIfPresent(Decimal.self, forKey: .stopDistance)
            switch (stopLevel, stopDistance) {
            case (.none, .none): stop = nil
            case (.none, let distance?): stop = .distance(distance)
            case (let level?, _): stop = .position(level: level)
            }
            if let stop = stop {
                let isGuaranteed = try container.decode(Bool.self, forKey: .isStopGuaranteed)
                let trailingDistance = try container.decodeIfPresent(Decimal.self, forKey: .stopTrailingDistance)
                let trailingIncrement = try container.decodeIfPresent(Decimal.self, forKey: .stopTrailingIncrement)
                
                let risk: API.Deal.Stop.Risk = (isGuaranteed) ? .limited(premium: nil) : .exposed
                let trailing: API.Deal.Stop.Trailing
                switch (trailingDistance, trailingIncrement) {
                case (.none, .none):
                    trailing = .static
                case (let distance?, let increment?):
                    trailing = .dynamic(.init(distance: distance, increment: increment))
                case (.some, .none):
                    throw DecodingError.keyNotFound(Self.CodingKeys.stopTrailingDistance,  .init(codingPath: container.codingPath, debugDescription: "The trailing increment/step couldn't be found (even when the trailing distance was set."))
                case (.none, .some):
                    throw DecodingError.keyNotFound(Self.CodingKeys.stopTrailingIncrement, .init(codingPath: container.codingPath, debugDescription: "The trailing distance couldn't be found (even when the trailing increment/step was set."))
                }
                self.stop = .init(stop, risk: risk, trailing: trailing)
            } else {
                self.stop = nil
            }
            // Figure out working order expiration.
            if let expirationString = try container.decodeIfPresent(String.self, forKey: .expiration) {
                if expirationString == "GTC" {
                    self.expiration = .tillCancelled
                } else {
                    guard let formatter = decoder.userInfo[API.JSON.DecoderKey.dateFormatter] as? DateFormatter else {
                        throw DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: "The date formatter supposed to be passed as user info couldn't be found.")
                    }
                    let date = try formatter.date(from: expirationString) ?! DecodingError.dataCorruptedError(forKey: .expiration, in: container, debugDescription: formatter.parseErrorLine(date: expirationString))
                    self.expiration = .tillDate(date)
                }
            } else {
                self.expiration = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case dealReference, actions, currency, direction
            case marketName, size
            case level, limitLevel, limitDistance
            case stopLevel, stopDistance, isStopGuaranteed = "guaranteedStop"
            case stopTrailingDistance = "trailingStopDistance", stopTrailingIncrement = "trailingStep"
            case expiration = "goodTillDate"
        }
    }
}

extension API.Activity.Details {
    /// Deal affected by an activity.
    public struct Action: Decodable {
        /// Action type.
        public let type: Self.Kind
        /// Affected deal identifier.
        public let dealIdentifier: API.Deal.Identifier
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        private enum CodingKeys: String, CodingKey {
            case type = "actionType"
            case dealIdentifier = "affectedDealId"
        }
        
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
            
            case workingOrderDeleted = "WORKING_ORDER_DELETED"
            
            case unknown = "UNKNOWN"
        }
    }
}
