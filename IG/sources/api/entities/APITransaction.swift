import Foundation
import Decimals

extension API {
    /// A financial transaction between accounts.
    public struct Transaction {
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
        public let size: (direction: IG.Deal.Direction, amount: Decimal64)?
        /// Open position level/price and date.
        public let open: (date: Date, level: Decimal64?)
        /// Close position level/price and date.
        public let close: (date: Date, level: Decimal64?)
        /// Realised profit and loss is the amount of money you have made or lost on a bet once the bet has been closed. Realised profit or loss will add or subtract from your cash balance.
        public let profitLoss: IG.Deal.ProfitLoss
        /// Boolean indicating whether this was a cash transaction.
        public let isCash: Bool
    }
}

extension API.Transaction {
    /// Transaction type.
    public enum Kind: Hashable {
        case deal
        case deposit
        case withdrawal
    }
}

// MARK: -

extension API.Transaction: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        
        self.type = try container.decode(Self.Kind.self, forKey: .type)
        self.reference = try container.decode(String.self, forKey: .reference)
        self.title = try container.decode(String.self, forKey: .title)
        self.period = try container.decodeIfPresent(IG.Market.Expiry.self, forKey: .period) ?? .none
        
        let sizeString = try container.decode(String.self, forKey: .size)
        if sizeString == "-" {
            self.size = nil
        } else if let size = Decimal64(sizeString) {
            switch size.sign {
            case .plus:  self.size = (.buy, size)
            case .minus: self.size = (.sell, size.magnitude)
            }
        } else {
            throw DecodingError.dataCorruptedError(forKey: .size, in: container, debugDescription: "The size string '\(sizeString)' couldn't be parsed into a number")
        }
        
        let openDate = try container.decode(Date.self, forKey: .openDate, with: DateFormatter.iso8601Broad)
        let openString = try container.decode(String.self, forKey: .openLevel)
        if openString == "-" {
            self.open = (openDate, nil)
        } else if let openLevel = Decimal64(openString) {
            self.open = (openDate, openLevel)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .openLevel, in: container, debugDescription: "The open level '\(openString)' couldn't be parsed into a number")
        }
        
        let closeDate = try container.decode(Date.self, forKey: .closeDate, with: DateFormatter.iso8601Broad)
        let closeString = try container.decode(String.self, forKey: .closeLevel)
        if let closeLevel = Decimal64(closeString) {
            self.close = (closeDate, (closeLevel == 0) ? nil : closeLevel)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .closeLevel, in: container, debugDescription: "The close level '\(closeString)' couldn't be parsed into a number")
        }
        
        let currencyInitial = try container.decode(String.self, forKey: .currency)
        guard let currency = Self._currency(from: currencyInitial) else {
            throw DecodingError.dataCorruptedError(forKey: .currency, in: container, debugDescription: "The currency initials '\(currencyInitial)' for this transaction couldn't be identified")
        }
        
        let profitString = try container.decode(String.self, forKey: .profitLoss)
        guard profitString.hasPrefix(currencyInitial) else {
            throw DecodingError.dataCorruptedError(forKey: .profitLoss, in: container, debugDescription: "The profit & loss string '\(profitString)' cannot be process with currency '\(currencyInitial)'")
        }
        
        var processedString = String(profitString[currencyInitial.endIndex...])
        processedString.removeAll { $0 == "," }
        guard let profitValue = Decimal64(processedString) else {
            throw DecodingError.dataCorruptedError(forKey: .profitLoss, in: container, debugDescription: "The profit & loss string '\(profitString)' cannot be transformed to a decimal number")
        }
        
        self.profitLoss = .init(value: profitValue, currency: currency)
        self.isCash = try container.decode(Bool.self, forKey: .isCash)
    }
    
    private enum _Keys: String, CodingKey {
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
    
    /// Transform the currency initial given into  a proper ISO currency.
    /// - note: These are retrieved from `market.intrument.currencies.symbol`.
    private static func _currency(from initial: String)-> Currency.Code? {
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

extension API.Transaction.Kind: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "DEAL": self = .deal
        case "DEPO": self = .deposit
        case "WITH": self = .withdrawal
        case let value: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid transaction type '\(value)'.")
        }
    }
}
