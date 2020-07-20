import Combine
import Foundation
import Decimals

extension API.Request.Accounts {
    
    // MARK: GET /history/activity
    
    /// Returns the account's activity history.
    ///
    /// **This is a paginated-request**, which means that the returned `Publisher` will forward downstream several values. Each value is actually an array of activities with `pageSize` number of elements.
    /// - attention: The results are returned from newest to oldest.
    /// - parameter from: The start date.
    /// - parameter to: The end date (if `nil` means the end of `from` date).
    /// - parameter detailed: Boolean indicating whether to retrieve additional details about the activity.
    /// - parameter filterBy: The filters that can be applied to the search. FIQL filter supporst operators: `==`, `!=`, `,`, and `;`
    /// - parameter pageSize: The number of activities returned per *page* (i.e. `Publisher` value). The valid range is between 10 and 500; anything beyond that will be clamped.
    /// - todo: validate `FIQL`.
    /// - returns: Combine `Publisher` forwarding multiple values. Each value represents an array of activities.
    public func getActivityContinuously(from: Date, to: Date? = nil, detailed: Bool, filterBy: (identifier: IG.Deal.Identifier?, FIQL: String?) = (nil, nil), arraySize pageSize: UInt = 50) -> AnyPublisher<[API.Activity],IG.Error> {
        self.api.publisher { (api) -> DateFormatter in
                guard let timezone = api.channel.credentials?.timezone else {
                    throw IG.Error(.api(.invalidRequest), "No credentials were found on the API instance.", help: "Log in before calling this request.")
                }
                
                if let fiql = filterBy.FIQL, !fiql.isEmpty {
                    throw IG.Error(.api(.invalidRequest), "THE FIQL filter cannot be empty.", help: "Read the request documentation and be sure to follow all requirements.")
                }
                
                return DateFormatter.iso8601Broad.deepCopy(timeZone: timezone)
            }.makeRequest(.get, "history/activity", version: 3, credentials: true, queries: { (dateFormatter) in
                var queries: [URLQueryItem] = [.init(name: "from", value: dateFormatter.string(from: from))]

                if let to = to {
                    queries.append(.init(name: "to", value: dateFormatter.string(from: to)))
                }

                if detailed {
                    queries.append(.init(name: "detailed", value: "true"))
                }

                if let dealIdentifier = filterBy.identifier {
                    queries.append(.init(name: "dealId", value: dealIdentifier.rawValue))
                }

                if let filter = filterBy.FIQL {
                    queries.append(.init(name: "filter", value: filter))
                }

                let size: UInt = (pageSize < 500) ? 500 :
                                 (pageSize > 10)  ? 10  : pageSize
                queries.append(.init(name: "pageSize", value: String(size)))
                return queries
            }).sendPaginating(request: { (api, initial, previous) -> URLRequest? in
                guard let previous = previous else {
                    return initial.request
                }
                
                guard let next = previous.metadata.next else {
                    return nil
                }

                guard let queries = URLComponents(string: next)?.queryItems else {
                    throw IG.Error(.api(.invalidRequest), "The paginated request for activities couldn't be processed because there were no 'next' queries.", help: "A unexpected error was encountered. Please contact the repository maintainer and attach this debug print.", info: ["Request": previous.request])
                }

                guard let from = queries.first(where: { $0.name == "from" }),
                      let to = queries.first(where: { $0.name == "to" }) else {
                    throw IG.Error(.api(.invalidRequest), "The paginated request for activies couldn't be processed because the 'from' and/or 'to' queries couldn't be found.", help: "A unexpected error was encountered. Please contact the repository maintainer and attach this debug print.", info: ["Request": previous.request])
                }

                return try initial.request.set { try $0.addQueries([from, to])}
            }, call: { (publisher, _) in
                publisher.send(expecting: .json, statusCode: 200)
                    .decodeJSON(decoder: .default(values: true)) { (response: _PagedActivities, _) in
                        (response.metadata.paging, response.activities)
                    }.mapError(errorCast)
            }).mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Response Entities

extension API.Request.Accounts {
    /// A single page of activity requests.
    private struct _PagedActivities: Decodable {
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
