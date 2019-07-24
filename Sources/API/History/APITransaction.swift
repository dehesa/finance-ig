import ReactiveSwift
import Foundation

extension API.Request.Transactions {
    
    // MARK: GET /history/transactions
    
    /// Returns the transaction history. By default returns the minue prices within the last 10 minutes.
    /// - parameter from: The start date.
    /// - parameter to: The end date (`nil` means "today").
    /// - parameter type: Filter for the transaction types being returned.
    /// - parameter page: Paging variables for the transactions page received (`0` means paging is disabled).
    public func get(from: Date, to: Date? = nil, type: Kind = .all, page: (size: UInt, number: UInt) = (20, 1)) -> SignalProducer<[API.Transaction],API.Error> {
        return SignalProducer(api: self.api) { (api) -> Foundation.DateFormatter in
                guard let timezone = api.session.credentials?.timezone else {
                    throw API.Error.invalidCredentials(nil, message: "No credentials found")
                }
            
                let formatter = API.DateFormatter.deepCopy(API.DateFormatter.iso8601NoTimezone)
                formatter.timeZone = timezone
                return formatter
            }.request(.get, "history/transactions", version: 2, credentials: true, queries: { (_, formatter) in
                var queries = [URLQueryItem(name: "from", value: formatter.string(from: from))]
                
                if let to = to {
                    queries.append(URLQueryItem(name: "to", value: formatter.string(from: to)))
                }
                
                if type != .all {
                    queries.append(URLQueryItem(name: "type", value: type.rawValue))
                }
                
                queries.append(URLQueryItem(name: "pageSize", value: String(page.size)))
                return queries
            }).paginate(request: { (_, initialRequest, previous) in
                let nextPage: UInt
                if let previous = previous {
                    guard let nextIteration = previous.meta.next else { return nil }
                    nextPage = nextIteration
                } else {
                    nextPage = 1
                }
                
                var request = initialRequest
                try request.addQueries([URLQueryItem(name: "pageNumber", value: String(nextPage))])
                return request
            }, endpoint: { (producer) -> SignalProducer<(Self.PagedTransactions.Metadata.Page,[API.Transaction]), API.Error> in
                producer.send(expecting: .json)
                    .validateLadenData(statusCodes: 200)
                    .decodeJSON()
                    .map { (response: Self.PagedTransactions) in
                        return (response.metadata.page, response.transactions)
                    }
            })
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to user's transactions.
    public struct Transactions {
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

extension API.Request.Transactions {
    /// Transaction type.
    public enum Kind: String {
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

extension API.Request.Transactions {
    /// A single Page of transactions request.
    private struct PagedTransactions: Decodable {
        let transactions: [API.Transaction]
        let metadata: Self.Metadata
        
        struct Metadata: Decodable {
            let page: Self.Page
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Self.CodingKeys.self)
                let subContainer = try container.nestedContainer(keyedBy: Self.Page.CodingKeys.self, forKey: .pageData)
                
                let size = try container.decode(UInt.self, forKey: .size)
                let number = try subContainer.decode(UInt.self, forKey: .pageNumber)
                let count = try subContainer.decode(UInt.self, forKey: .totalPages)
                self.page = Page(number: number, size: size, count: count)
            }
            
            private enum CodingKeys: String, CodingKey {
                case size, pageData
            }
            
            struct Page {
                /// The page number.
                let number: UInt
                /// The total amount of transactions that the current page can hold.
                let size: UInt
                /// The total number of pages.
                let count: UInt
                /// Returns the next page number if there are more to go (`nil` otherwise).
                var next: UInt? {
                    return self.number < self.count ? self.number + 1 : nil
                }
                
                enum CodingKeys: String, CodingKey {
                    case pageSize, pageNumber, totalPages
                }
            }
        }
    }
}

extension API {
    /// A financial transaction between accounts.
    public struct Transaction: Decodable {
        /// The type of transaction.
        public let type: Self.Kind
        /// Deal Reference.
        public let reference: String
        /// Instrument name.
        public let description: String
        /// Instrument expiry period.
        public let period: API.Expiry
        /// Internation currency code.
        public let currency: String
        /// Formatted order size, including the direction (`+` for buy, `-` for sell).
        public let size: Double?
        /// Open position level/price and date.
        public let open: (date: Date, level: Double?)
        /// Close position level/price and date.
        public let close: (date: Date, level: Double?)
        /// Realised profit and loss is the amount of money you have made or lost on a bet once the bet has been closed. Realised profit or loss will add or subtract from your cash balance.
        public let profitLoss: String
        /// Boolean indicating whether this was a cash transaction.
        public let isCash: Bool
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            self.type = try container.decode(Self.Kind.self, forKey: .type)
            self.reference = try container.decode(String.self, forKey: .reference)
            
            self.description = try container.decode(String.self, forKey: .description)
            self.period = try container.decodeIfPresent(API.Expiry.self, forKey: .period) ?? .none
            self.currency = try container.decode(String.self, forKey: .currency)
            
            let sizeString = try container.decode(String.self, forKey: .size)
            if sizeString == "-" {
                self.size = nil
            } else if let size = Double(sizeString) {
                self.size = size
            } else {
                throw DecodingError.dataCorruptedError(forKey: .size, in: container, debugDescription: "The size string \"\(sizeString)\" couldn't be parsed into a number")
            }
            
            let openDate = try container.decode(Date.self, forKey: .openDate, with: API.DateFormatter.iso8601NoTimezone)
            let openString = try container.decode(String.self, forKey: .openLevel)
            if openString == "-" {
                self.open = (openDate, nil)
            } else if let openLevel = Double(openString) {
                self.open = (openDate, openLevel)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .openLevel, in: container, debugDescription: "The open level \"\(openString)\" couldn't be parsed into a number.")
            }
            
            
            let closeDate = try container.decode(Date.self, forKey: .closeDate, with: API.DateFormatter.iso8601NoTimezone)
            let closeString = try container.decode(String.self, forKey: .closeLevel)
            if let closeLevel = Double(closeString) {
                self.close = (closeDate, (closeLevel == 0) ? nil : closeLevel)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .closeLevel, in: container, debugDescription: "The close level \"\(closeString)\" couldn't be parsed into a number.")
            }
            
            self.profitLoss = try container.decode(String.self, forKey: .profitLoss)
            self.isCash = try container.decode(Bool.self, forKey: .isCash)
        }
        
        private enum CodingKeys: String, CodingKey {
            case type = "transactionType"
            case reference
            case description = "instrumentName"
            case period, currency, size
            case openDate = "openDateUtc"
            case openLevel
            case closeDate = "dateUtc"
            case closeLevel = "closeLevel"
            case profitLoss = "profitAndLoss"
            case isCash = "cashTransaction"
        }
    }
}

extension API.Transaction {
    /// Transaction type.
    public enum Kind: String, Decodable {
        case deal = "DEAL"
        case deposit = "DEPO"
        case withdrawal = "WITH"
    }
}
