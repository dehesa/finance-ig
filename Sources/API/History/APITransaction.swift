import Combine
import Foundation

extension IG.API.Request.History {
    
    // MARK: GET /history/transactions
    
    /// Returns the transaction history.
    ///
    /// The *constinuous* version of this endpoint is preferred. Depending on the amount of transactions performed, this endpoint may take a long time or it may fail.
    /// - parameter from: The start date.
    /// - parameter to: The end date (`nil` means "today").
    /// - parameter type: Filter for the transaction types being returned.
    public func getTransactions(from: Date, to: Date? = nil, type: Self.Transaction = .all) -> IG.API.DiscretePublisher<[IG.API.Transaction]> {
        self.api.publisher { (api) -> DateFormatter in
                guard let timezone = api.session.credentials?.timezone else {
                    throw IG.API.Error.invalidRequest(.noCredentials, suggestion: .logIn)
                }
                return IG.API.Formatter.iso8601Broad.deepCopy(timeZone: timezone)
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
            .mapError(IG.API.Error.transform)
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
    public func getTransactionsContinuously(from: Date, to: Date? = nil, type: Self.Transaction = .all, array page: (size: Int, number: Int) = (20, 1)) -> IG.API.ContinuousPublisher<[IG.API.Transaction]> {
        self.api.publisher { (api) -> DateFormatter in
                guard let timezone = api.session.credentials?.timezone else {
                    throw IG.API.Error.invalidRequest(.noCredentials, suggestion: .logIn)
                }
                guard page.size > 0 else {
                    throw IG.API.Error.invalidRequest(.init(#"The page size must be greater than zero; however, "\#(page.size)" was provided instead"#), suggestion: .readDocs)
                }
                guard page.number > 0 else {
                    throw IG.API.Error.invalidRequest(.init(#"The page number must be greater than zero; however, "\#(page.number)" was provided instead"#), suggestion: .readDocs)
                }
                return IG.API.Formatter.iso8601Broad.deepCopy(timeZone: timezone)
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
                    .decodeJSON(decoder: .default()) { (response: Self.PagedTransactions, _) in
                        (response.metadata.page, response.transactions)
                    }.mapError(IG.API.Error.transform)
            }).mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.API.Request.History {
    /// Transaction type.
    public enum Transaction: String {
        case all = "ALL"
        case deal = "ALL_DEAL"
        case deposit = "DEPOSIT"
        case withdrawal = "WITHDRAWAL"
        
        public init(_ type: IG.API.Transaction.Kind) {
            switch type {
            case .deal: self = .deal
            case .deposit: self = .deposit
            case .withdrawal: self = .withdrawal
            }
        }
    }
}

extension IG.API.Request.History {
    /// A single Page of transactions request.
    private struct PagedTransactions: Decodable {
        let transactions: [IG.API.Transaction]
        let metadata: Self.Metadata
        
        struct Metadata: Decodable {
            let page: Self.Page
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Self.CodingKeys.self)
                let subContainer = try container.nestedContainer(keyedBy: Self.Page.CodingKeys.self, forKey: .pageData)
                
                let size = try container.decode(Int.self, forKey: .size)
                let number = try subContainer.decode(Int.self, forKey: .pageNumber)
                let count = try subContainer.decode(Int.self, forKey: .totalPages)
                self.page = Page(number: number, size: size, count: count)
            }
            
            private enum CodingKeys: String, CodingKey {
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
                var next: Int? {
                    return self.number < self.count ? self.number + 1 : nil
                }
                
                enum CodingKeys: String, CodingKey {
                    case pageSize, pageNumber, totalPages
                }
            }
        }
    }
}

extension IG.API {
    /// A financial transaction between accounts.
    public struct Transaction: Decodable {
        /// The type of transaction.
        public let type: Self.Kind
        /// Deal Reference.
        /// - note: It seems to be a substring of the actual `dealId`.
        public let reference: String
        /// Instrument name.
        ///
        /// For example: `EUR/USD Mini converted at 0.902239755`
        public let title: String
        /// Instrument expiry period.
        public let period: IG.Market.Expiry
        /// Formatted order size, including the direction (`+` for buy, `-` for sell).
        public let size: (direction: IG.Deal.Direction, amount: Decimal)?
        /// Open position level/price and date.
        public let open: (date: Date, level: Decimal?)
        /// Close position level/price and date.
        public let close: (date: Date, level: Decimal?)
        /// Realised profit and loss is the amount of money you have made or lost on a bet once the bet has been closed. Realised profit or loss will add or subtract from your cash balance.
        public let profitLoss: IG.Deal.ProfitLoss
        /// Boolean indicating whether this was a cash transaction.
        public let isCash: Bool
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            self.type = try container.decode(Self.Kind.self, forKey: .type)
            self.reference = try container.decode(String.self, forKey: .reference)
            self.title = try container.decode(String.self, forKey: .title)
            self.period = try container.decodeIfPresent(IG.Market.Expiry.self, forKey: .period) ?? .none
            
            let sizeString = try container.decode(String.self, forKey: .size)
            if sizeString == "-" {
                self.size = nil
            } else if let size = Decimal(string: sizeString) {
                switch size.sign {
                case .plus:  self.size = (.buy, size)
                case .minus: self.size = (.sell, size.magnitude)
                }
            } else {
                throw DecodingError.dataCorruptedError(forKey: .size, in: container, debugDescription: "The size string \"\(sizeString)\" couldn't be parsed into a number")
            }
            
            let openDate = try container.decode(Date.self, forKey: .openDate, with: IG.API.Formatter.iso8601Broad)
            let openString = try container.decode(String.self, forKey: .openLevel)
            if openString == "-" {
                self.open = (openDate, nil)
            } else if let openLevel = Decimal(string: openString) {
                self.open = (openDate, openLevel)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .openLevel, in: container, debugDescription: "The open level \"\(openString)\" couldn't be parsed into a number")
            }
            
            let closeDate = try container.decode(Date.self, forKey: .closeDate, with: IG.API.Formatter.iso8601Broad)
            let closeString = try container.decode(String.self, forKey: .closeLevel)
            if let closeLevel = Decimal(string: closeString) {
                self.close = (closeDate, (closeLevel == 0) ? nil : closeLevel)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .closeLevel, in: container, debugDescription: "The close level \"\(closeString)\" couldn't be parsed into a number")
            }
            
            let currencyInitial = try container.decode(String.self, forKey: .currency)
            guard let currency = Self.currency(from: currencyInitial) else {
                throw DecodingError.dataCorruptedError(forKey: .currency, in: container, debugDescription: "The currency initials \"\(currencyInitial)\" for this transaction couldn't be identified")
            }
            
            let profitString = try container.decode(String.self, forKey: .profitLoss)
            guard profitString.hasPrefix(currencyInitial) else {
                throw DecodingError.dataCorruptedError(forKey: .profitLoss, in: container, debugDescription: "The profit & loss string \"\(profitString)\" cannot be process with currency \"\(currencyInitial)\"")
            }
            
            var processedString = String(profitString[currencyInitial.endIndex...])
            processedString.removeAll { $0 == "," }
            guard let profitValue = Decimal(string: processedString) else {
                throw DecodingError.dataCorruptedError(forKey: .profitLoss, in: container, debugDescription: "The profit & loss string \"\(profitString)\" cannot be transformed to a decimal number")
            }
            
            self.profitLoss = .init(value: profitValue, currency: currency)
            self.isCash = try container.decode(Bool.self, forKey: .isCash)
        }
        
        private enum CodingKeys: String, CodingKey {
            case type = "transactionType"
            case reference
            case title = "instrumentName"
            case period, size
            case openDate = "openDateUtc"
            case openLevel
            case closeDate = "dateUtc"
            case closeLevel = "closeLevel"
            case profitLoss = "profitAndLoss", currency
            case isCash = "cashTransaction"
        }
    }
}

extension IG.API.Transaction {
    /// Transaction type.
    public enum Kind: String, Decodable {
        case deal = "DEAL"
        case deposit = "DEPO"
        case withdrawal = "WITH"
    }
    
    /// Transform the currency initial given into  a proper ISO currency.
    /// - note: These are retrieved from `market.intrument.currencies.symbol`.
    private static func currency(from initial: String)-> IG.Currency.Code? {
        switch initial {
        case "E": return .eur
        case "$": return .usd
        case "¥": return .jpy
        case "£": return .gbp
        case "SF": return .chf
        case "CD": return .cad
        case "A$": return .aud
        case "NZ": return .nzd
        case "SD": return .sgd
        case "MP": return .mxn
        case "NK": return .nok
        case "SK": return .sek
        case "DK": return .dkk
        case "PZ": return .pln
        case "CK": return .czk
        case "HF": return .huf
        case "TL": return .try
        case "HK": return .hkd
        case "SR": return .zar
        default: return nil
        }
    }
}

// MARK: - Functionality

extension IG.API.Transaction: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("type", self.type)
        result.append("reference", self.reference)
        result.append("title", self.title)
        result.append("period", self.period.debugDescription)
        result.append("size", self.size.map { "\($0.direction) \($0.amount)" })
        
        let formatter = IG.API.Formatter.timestamp.deepCopy(timeZone: .current)
        result.append("open date", self.open.date, formatter: formatter)
        result.append("close date", self.close.date, formatter: formatter)
        let nilSym = IG.DebugDescription.Symbol.nil
        result.append("open/close levels", "\(self.open.level.map { String(describing: $0) } ?? nilSym)/\(self.close.level.map { String(describing: $0) } ?? nilSym)")
        result.append("P&L", self.profitLoss.description)
        result.append("cash", self.isCash)
        return result.generate()
    }
}
