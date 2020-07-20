import Combine
import Foundation
import Decimals

extension API.Request.Accounts {
    
    // MARK: GET /history/transactions
    
    /// Returns the transaction history.
    ///
    /// The *constinuous* version of this endpoint is preferred. Depending on the amount of transactions performed, this endpoint may take a long time or it may fail.
    /// - parameter from: The start date.
    /// - parameter to: The end date (`nil` means "today").
    /// - parameter type: Filter for the transaction types being returned.
    public func getTransactions(from: Date, to: Date? = nil, type: Self.Transaction = .all) -> AnyPublisher<[API.Transaction],IG.Error> {
        self.api.publisher { (api) -> DateFormatter in
                guard let timezone = api.channel.credentials?.timezone else {
                    throw IG.Error(.api(.invalidRequest), "No credentials were found on the API instance.", help: "Log in before calling this request.")
                }
                return DateFormatter.iso8601Broad.deepCopy(timeZone: timezone)
            }.makeRequest(.get, "history/transactions", version: 2, credentials: true, queries: { (dateFormatter) in
                var queries: [URLQueryItem] = [.init(name: "from", value: dateFormatter.string(from: from))]

                if let to = to {
                    queries.append(.init(name: "to", value: dateFormatter.string(from: to)))
                }

                if type != .all {
                    queries.append(.init(name: "type", value: type.rawValue))
                }

                queries.append(.init(name: "pageSize", value: "0"))
                queries.append(.init(name: "pageNumber", value: "1"))
                return queries
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /history/transactions
    
    /// Returns the transaction history.
    ///
    /// **This is a paginated-request**, which means that the returned `Publisher` will forward downstream several values. Each value is actually an array of transactions with `array.size` number of elements.
    /// - precondition: `value.size` and `value.number` must be greater than zero.
    /// - parameter from: The start date.
    /// - parameter to: The end date (`nil` means "today").
    /// - parameter type: Filter for the transaction types being returned.
    /// - parameter page: Paging variables for the transactions page received. `page.size` references the amount of transactions forward per value.
    /// - returns: Combine `Publisher` forwarding multiple values. Each value represents an array of transactions.
    public func getTransactionsContinuously(from: Date, to: Date? = nil, type: Self.Transaction = .all, array page: (size: Int, number: Int) = (20, 1)) -> AnyPublisher<[API.Transaction],IG.Error> {
        self.api.publisher { (api) -> DateFormatter in
                guard let timezone = api.channel.credentials?.timezone else {
                    throw IG.Error(.api(.invalidRequest), "No credentials were found on the API instance.", help: "Log in before calling this request.")
                }
                guard page.size > 0 else {
                    throw IG.Error(.api(.invalidRequest), "The page size must be greater than zero; however, '\(page.size)' was provided instead.", help: "Read the request documentation and be sure to follow all requirements.")
                }
                guard page.number > 0 else {
                    throw IG.Error(.api(.invalidRequest), "The page number must be greater than zero; however, '\(page.number)' was provided instead.", help: "Read the request documentation and be sure to follow all requirements.")
                }
                return DateFormatter.iso8601Broad.deepCopy(timeZone: timezone)
            }.makeRequest(.get, "history/transactions", version: 2, credentials: true, queries: { (dateFormatter) in
                var queries: [URLQueryItem] = [.init(name: "from", value: dateFormatter.string(from: from))]

                if let to = to {
                    queries.append(.init(name: "to", value: dateFormatter.string(from: to)))
                }

                if type != .all {
                    queries.append(.init(name: "type", value: type.rawValue))
                }

                queries.append(.init(name: "pageSize", value: String(page.size)))
                return queries
            }).sendPaginating(request: { (_, initial, previous) -> URLRequest? in
                let nextPage: Int
                if let previous = previous {
                    guard let nextIteration = previous.metadata.next else { return nil }
                    nextPage = nextIteration
                } else {
                    nextPage = page.number
                }
                
                return try initial.request.set { try $0.addQueries([.init(name: "pageNumber", value: String(nextPage))]) }
            }, call: { (publisher, _) in
                publisher.send(expecting: .json, statusCode: 200)
                    .decodeJSON(decoder: .default()) { (response: _PagedTransactions, _) in
                        (response.metadata.page, response.transactions)
                    }.mapError(errorCast)
            }).mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

extension API.Request.Accounts {
    /// Transaction type.
    public enum Transaction: String {
        case all = "ALL"
        case deal = "ALL_DEAL"
        case deposit = "DEPOSIT"
        case withdrawal = "WITHDRAWAL"
        
        public init(_ type: API.Transaction.Kind) {
            switch type {
            case .deal: self = .deal
            case .deposit: self = .deposit
            case .withdrawal: self = .withdrawal
            }
        }
    }
}

// MARK: Response Entities

extension API.Request.Accounts {
    /// A single Page of transactions request.
    private struct _PagedTransactions: Decodable {
        let transactions: [API.Transaction]
        let metadata: Self.Metadata
        
        struct Metadata: Decodable {
            let page: Self.Page
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: _CodingKeys.self)
                let subContainer = try container.nestedContainer(keyedBy: Self.Page.CodingKeys.self, forKey: .pageData)
                
                let size = try container.decode(Int.self, forKey: .size)
                let number = try subContainer.decode(Int.self, forKey: .pageNumber)
                let count = try subContainer.decode(Int.self, forKey: .totalPages)
                self.page = Page(number: number, size: size, count: count)
            }
            
            private enum _CodingKeys: String, CodingKey {
                case size, pageData
            }
            
            struct Page {
                /// The page number.
                let number: Int
                /// The total amount of transactions that the current page can hold.
                let size: Int
                /// The total number of pages.
                let count: Int
                /// Returns the next page number if there are more to go (`nil` otherwise).
                var next: Int? { self.number < self.count ? self.number + 1 : nil }
                
                enum CodingKeys: String, CodingKey {
                    case pageSize, pageNumber, totalPages
                }
            }
        }
    }
}
