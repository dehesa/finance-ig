import ReactiveSwift
import Foundation

extension IG.API.Request.History {
    
    // MARK: GET /history/transactions
    
    /// Returns the transaction history. By default returns the minue prices within the last 10 minutes.
    ///
    /// **This is a paginated-request**, which means that the `SignalProducer` will return several value events with an array of transactions (as indicated by the `page.size`).
    /// - parameter from: The start date.
    /// - parameter to: The end date (`nil` means "today").
    /// - parameter type: Filter for the transaction types being returned.
    /// - parameter page: Paging variables for the transactions page received (`0` means paging is disabled).
    public func getTransactions(from: Date, to: Date? = nil, type: Self.Transaction = .all, page: (size: UInt, number: UInt) = (20, 1)) -> SignalProducer<[IG.API.Transaction],IG.API.Error> {
        return SignalProducer(api: self.api) { (api) -> DateFormatter in
                guard let timezone = api.session.credentials?.timezone else {
                    throw IG.API.Error.invalidRequest(IG.API.Error.Message.noCredentials, suggestion: IG.API.Error.Suggestion.logIn)
                }
                return IG.API.Formatter.iso8601.deepCopy.set { $0.timeZone = timezone }
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
            }, endpoint: { (producer) -> SignalProducer<(Self.PagedTransactions.Metadata.Page,[IG.API.Transaction]), IG.API.Error> in
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

// MARK: Request Entities

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

// MARK: Response Entities

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
        public let profitLoss: IG.API.Deal.ProfitLoss
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
            
            let openDate = try container.decode(Date.self, forKey: .openDate, with: IG.API.Formatter.iso8601)
            let openString = try container.decode(String.self, forKey: .openLevel)
            if openString == "-" {
                self.open = (openDate, nil)
            } else if let openLevel = Decimal(string: openString) {
                self.open = (openDate, openLevel)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .openLevel, in: container, debugDescription: "The open level \"\(openString)\" couldn't be parsed into a number.")
            }
            
            let closeDate = try container.decode(Date.self, forKey: .closeDate, with: IG.API.Formatter.iso8601)
            let closeString = try container.decode(String.self, forKey: .closeLevel)
            if let closeLevel = Decimal(string: closeString) {
                self.close = (closeDate, (closeLevel == 0) ? nil : closeLevel)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .closeLevel, in: container, debugDescription: "The close level \"\(closeString)\" couldn't be parsed into a number.")
            }
            
            let currencyInitial = try container.decode(String.self, forKey: .currency)
            guard let currency = Self.currency(from: currencyInitial) else {
                throw DecodingError.dataCorruptedError(forKey: .currency, in: container, debugDescription: "The currency initials \"\(currencyInitial)\" for this transaction couldn't be identified.")
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
    /// - todo: Figure out other currencies. Currently there is only €.
    private static func currency(from initial: String)-> IG.Currency.Code? {
        switch initial {
        case "E": return .eur
        case "$": return .usd
        case "¥": return .jpy
        default:
            #warning("Look for more in: market.intrument.currencies.symbol")
            return nil
        }
    }
}
