import ReactiveSwift
import Foundation

extension API {
    /// Returns the transaction history. By default returns the minue prices within the last 10 minutes.
    /// - parameter from: The start date.
    /// - parameter to: The end date (if `nil` means "today").
    /// - parameter type: Filter for the transaction types being returned.
    /// - parameter page: Paging variables for the transactions page received.
    public func transactions(from: Date, to: Date? = nil, type: API.Request.Transaction.Kind = .all, page: (size: UInt, number: UInt) = (20, 1)) -> SignalProducer<[API.Response.Transaction],API.Error> {
        return SignalProducer(api: self)
            .request(.get, "history/transactions", version: 2, credentials: true, queries: { (_,_) -> [URLQueryItem] in
                var queries = [URLQueryItem(name: "from", value: API.DateFormatter.iso8601NoTimezone.string(from: from))]
                
                if let to = to {
                    queries.append(URLQueryItem(name: "to", value: API.DateFormatter.iso8601NoTimezone.string(from: to)))
                }
                
                if type != .all {
                    queries.append(URLQueryItem(name: "type", value: type.rawValue))
                }
                
                queries.append(URLQueryItem(name: "pageSize", value: String(page.size)))
                return queries
            }).paginate(request: { (_, initialRequest, previous) -> URLRequest? in
                let nextPage: UInt
                if let previous = previous {
                    guard let nextIteration = previous.meta.next else { return nil }
                    nextPage = nextIteration
                } else {
                    nextPage = 1
                }
                
                var request = initialRequest
                try request.addQueries( [URLQueryItem(name: "pageNumber", value: String(nextPage))] )
                return request
            }, endpoint: { (producer) -> SignalProducer<(API.Response.PagedTransactions.Metadata.Page,[API.Response.Transaction]), API.Error> in
                producer.send(expecting: .json)
                    .validateLadenData(statusCodes: [200])
                    .decodeJSON()
                    .map { (response: API.Response.PagedTransactions) in
                        return (response.metadata.page, response.transactions)
                    }
            })
    }
}

// MARK: -

extension API.Request {
    /// Transaction request properties.
    public enum Transaction {
        /// Transaction type.
        public enum Kind: String {
            case all = "ALL"
            case deal = "ALL_DEAL"
            case deposit = "DEPOSIT"
            case withdrawal = "WITHDRAWAL"
            
            internal init(_ type: API.Response.Transaction.Kind) {
                switch type {
                case .deal: self = .deal
                case .deposit: self = .deposit
                case .withdrawal: self = .withdrawal
                }
            }
        }
    }
}

// MARK: -

extension API.Response {
    /// Single Page of transactions request.
    internal struct PagedTransactions: Decodable {
        /// Wrapper around the queried transactions.
        let transactions: [API.Response.Transaction]
        /// Metadata information about the current request.
        let metadata: Metadata
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        /// Page's extra information.
        internal struct Metadata: Decodable {
            /// Variables related to the current page.
            let page: Page
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let subContainer = try container.nestedContainer(keyedBy: Page.CodingKeys.self, forKey: .pageData)
                
                let size = try container.decode(UInt.self, forKey: .size)
                let number = try subContainer.decode(UInt.self, forKey: .pageNumber)
                let count = try subContainer.decode(UInt.self, forKey: .totalPages)
                self.page = Page(number: number, size: size, count: count)
            }
            
            private enum CodingKeys: String, CodingKey {
                case size, pageData
            }
            
            /// Variables for the current page.
            internal struct Page {
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
                
                fileprivate enum CodingKeys: String, CodingKey {
                    case pageSize, pageNumber, totalPages
                }
            }
        }
    }
}

extension API.Response {
    /// A financial transaction between accounts.
    public struct Transaction: Decodable {
        /// The type of transaction.
        let type: Kind
        /// Deal Reference.
        let reference: String
        /// Instrument used on the transaction.
        let instrument: Instrument
        /// Formatted order size, including the direction (`+` for buy, `-` for sell).
        let size: String
        /// Open position level/price and date.
        let open: (level: String, date: Date)
        /// Close position level/price and date.
        let close: (level: String, date: Date)
        /// Realised profit and loss is the amount of money you have made or lost on a bet once the bet has been closed. Realised profit or loss will add or subtract from your cash balance.
        let profitLoss: String
        /// Boolean indicating whether this was a cash transaction.
        let isCash: Bool
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.type = try container.decode(Kind.self, forKey: .type)
            self.reference = try container.decode(String.self, forKey: .reference)
            self.instrument = try Instrument(from: decoder)
            self.size = try container.decode(String.self, forKey: .size)
            let openLevel = try container.decode(String.self, forKey: .openLevel)
            let openDate = try container.decode(Date.self, forKey: .openDate, with: API.DateFormatter.iso8601NoTimezone)
            self.open = (openLevel, openDate)
            let closeLevel = try container.decode(String.self, forKey: .closeLevel)
            let closeDate = try container.decode(Date.self, forKey: .closeDate, with: API.DateFormatter.iso8601NoTimezone)
            self.close = (closeLevel, closeDate)
            self.profitLoss = try container.decode(String.self, forKey: .profitLoss)
            self.isCash = try container.decode(Bool.self, forKey: .isCash)
        }
        
        private enum CodingKeys: String, CodingKey {
            case type = "transactionType"
            case reference
            case size
            case openLevel
            case openDate = "openDateUtc"
            case closeLevel = "closeLevel"
            case closeDate = "dateUtc"
            case profitLoss = "profitAndLoss"
            case isCash = "cashTransaction"
        }
        
        /// Transaction type.
        public enum Kind: String, Decodable {
            case deal = "DEAL"
            case deposit = "DEPO"
            case withdrawal = "WITH"
        }
    }
}

extension API.Response.Transaction {
    /// Market's instrument properties.
    public struct Instrument: Decodable {
        /// Instrument name.
        public let name: String
        /// Instrument expiry period.
        public let expiry: API.Expiry
        /// Internation currency code.
        public let currency: String
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.expiry = try container.decodeIfPresent(API.Expiry.self, forKey: .expiry) ?? .none
            self.currency = try container.decode(String.self, forKey: .currency)
        }
        
        private enum CodingKeys: String, CodingKey {
            case name = "instrumentName"
            case expiry = "period"
            case currency
        }
    }
}
