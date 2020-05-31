/// Base for all monetary units
public protocol CurrencyType {
    /// Three letter code standardize by ISO 4217.
    static var code: Currency.Code { get }
    /// The standard name for the currency.
    static var name: String { get }
    /// The number of decimal places used to express any minor units for the currency.
    static var minorUnit: Int { get }
    /// The country where this currency is minted.
    static var country: String { get }
}

/// Namespace for currencies.
public enum Currency {
    /// ISO 4217 currency codes.
    public enum Code: String, ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable, Codable {
        /// Canadian Dollar.
        case cad = "CAD"
        /// United States Dollar.
        case usd = "USD"
        /// Mexican Peso.
        case mxn = "MXN"
        /// Brazilian Real.
        case brl = "BRL"
        /// British Pound Sterling.
        case gbp = "GBP"
        /// Norwegian Krone.
        case nok = "NOK"
        /// Swedish Krona.
        case sek = "SEK"
        /// Danish Krone.
        case dkk = "DKK"
        /// European Union Euro.
        case eur = "EUR"
        /// Swiss Franc.
        case chf = "CHF"
        /// Czech Koruna.
        case czk = "CZK"
        /// Hungarian Forint.
        case huf = "HUF"
        /// Polish Zloty.
        case pln = "PLN"
        /// Russian Ruble.
        case rub = "RUB"
        /// Turkish Lira.
        case `try` = "TRY"
        /// South African Rand.
        case zar = "ZAR"
        /// Indian Rupee.
        case inr = "INR"
        /// Singapore Dollar.
        case sgd = "SGD"
        /// Chinese Yuan Renminbi
        case cny = "CNY"
        /// Hong Kong Dollar
        case hkd = "HKD"
        /// New Taiwan Dollar.
        case twd = "TWD"
        /// South Korean Won.
        case krw = "KRW"
        /// Japanese Yen.
        case jpy = "JPY"
        /// Philippine Piso.
        case php = "PHP"
        /// Indonesian Rupiah.
        case idr = "IDR"
        /// Australian Dollar.
        case aud = "AUD"
        /// New Zealand Dollar.
        case nzd = "NZD"
        
        public init(stringLiteral value: String) {
            let currency = Self.init(rawValue: value) ?! fatalError("The given string '\(value)' couldn't be identified as a currency")
            self = currency
        }
        
        public init?(rawValue: String) {
            guard rawValue.utf8.count == 3 else { return nil }
            
            switch rawValue {
            case "CAD": self = .cad
            case "USD": self = .usd
            case "MXN": self = .mxn
            case "BRL": self = .brl
            case "GBP": self = .gbp
            case "NOK": self = .nok
            case "SEK": self = .sek
            case "DKK": self = .dkk
            case "EUR": self = .eur
            case "CHF": self = .chf
            case "CZK": self = .czk
            case "HUF": self = .huf
            case "PLN": self = .pln
            case "RUB": self = .rub
            case "TRY", "TRL": self = .try
            case "ZAR": self = .zar
            case "INR": self = .inr
            case "SGD": self = .sgd
            case "CNY", "CNH": self = .cny
            case "HKD": self = .hkd
            case "TWD": self = .twd
            case "KRW": self = .krw
            case "JPY": self = .jpy
            case "PHP": self = .php
            case "IDR": self = .idr
            case "AUD": self = .aud
            case "NZD": self = .nzd
            default: return nil
            }
        }
        
        @_transparent public init?(_ description: String) {
            self.init(rawValue: description)
        }
        
        @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        @_transparent public var description: String {
            self.rawValue
        }
    }
}

// MARK: - Currency List

extension Currency {
    /// Canadian Dollar.
    public enum CAD: CurrencyType {
        public static var code: Currency.Code { .cad }
        public static var name: String { "Canadian Dollar" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Canada" }
    }
    
    /// United States Dollar.
    public enum USD: CurrencyType {
        public static var code: Currency.Code { .usd }
        public static var name: String { "US Dollar" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "United States" }
    }
    
    /// Mexican Peso.
    public enum MXN: CurrencyType {
        public static var code: Currency.Code { .mxn }
        public static var name: String { "Mexican Peso" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Mexico" }
    }
    
    /// Brazilian Real.
    public enum BRL: CurrencyType {
        public static var code: Currency.Code { .brl }
        public static var name: String { "Brazilian Real" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Brazil" }
    }
    
    /// British Pound Sterling.
    public enum GBP: CurrencyType {
        public static var code: Currency.Code { .gbp }
        public static var name: String { "Pound Sterling" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Great Britian" }
    }
    
    /// Norwegian Krone.
    public enum NOK: CurrencyType {
        public static var code: Currency.Code { .nok }
        public static var name: String { "Norwegian Krone" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Norway" }
    }
    
    /// Swedish Krona.
    public enum SEK: CurrencyType {
        public static var code: Currency.Code { .sek }
        public static var name: String { "Swedish Krona" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Sweden" }
    }
    
    /// Danish Krone.
    public enum DKK: CurrencyType {
        public static var code: Currency.Code { .dkk }
        public static var name: String { "Danish Krone" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Denmark" }
    }
    
    /// European Union Euro.
    public enum EUR: CurrencyType {
        public static var code: Currency.Code { .eur }
        public static var name: String { "Euro" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Europe" }
    }
    
    /// Swiss Franc.
    public enum CHF: CurrencyType {
        public static var code: Currency.Code { .chf }
        public static var name: String { "Swiss Franc" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Switzerland" }
    }
    
    /// Czech Koruna.
    public enum CZK: CurrencyType {
        public static var code: Currency.Code { .czk }
        public static var name: String { "Czech Koruna" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Czech Republic" }
    }
    
    /// Hungarian Forint.
    public enum HUF: CurrencyType {
        public static var code: Currency.Code { .huf }
        public static var name: String { "Forint" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Hungary" }
    }
    
    /// Polish Zloty.
    public enum PLN: CurrencyType {
        public static var code: Currency.Code { .pln }
        public static var name: String { "Zloty" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Poland" }
    }
    
    /// Russian Ruble.
    public enum RUB: CurrencyType {
        public static var code: Currency.Code { .rub }
        public static var name: String { "Russian Ruble" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Russia" }
    }
    
    /// Turkish Lira.
    public enum TRY: CurrencyType {
        public static var code: Currency.Code { .try }
        public static var name: String { "Turkish Lira" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Turkey" }
    }
    
    /// South African Rand.
    public enum ZAR: CurrencyType {
        public static var code: Currency.Code { .zar }
        public static var name: String { "Rand" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "South Africa" }
    }
    
    /// Indian Rupee.
    public enum INR: CurrencyType {
        public static var code: Currency.Code { .inr }
        public static var name: String { "Indian Rupee" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "India" }
    }
    
    /// Singapore Dollar.
    public enum SGD: CurrencyType {
        public static var code: Currency.Code { .sgd }
        public static var name: String { "Singapore Dollar" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Singapore" }
    }
    
    /// Chinese Yuan Renminbi
    public enum CNY: CurrencyType {
        public static var code: Currency.Code { .cny }
        public static var name: String { "Yuan Renminbi" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "China" }
    }
    
    /// Hong Kong Dollar
    public enum HKD: CurrencyType {
        public static var code: Currency.Code { .hkd }
        public static var name: String { "Hong Kong Dollar" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "China" }
    }
    
    /// New Taiwan Dollar.
    public enum TWD: CurrencyType {
        public static var code: Currency.Code { .twd }
        public static var name: String { "New Taiwan Dollar" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "New Taiwan" }
    }
    
    /// South Korean Won.
    public enum KRW: CurrencyType {
        public static var code: Currency.Code { .krw }
        public static var name: String { "Won" }
        public static var minorUnit: Int { 0 }
        public static var country: String { "Korea" }
    }
    
    /// Japanese Yen.
    public enum JPY: CurrencyType {
        public static var code: Currency.Code { .jpy }
        public static var name: String { "Yen" }
        public static var minorUnit: Int { 0 }
        public static var country: String { "Japan" }
    }
    
    /// Philippine Piso.
    public enum PHP: CurrencyType {
        public static var code: Currency.Code { .php }
        public static var name: String { "Philippine Piso" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Philippines" }
    }
    
    /// Indonesian Rupiah.
    public enum IDR: CurrencyType {
        public static var code: Currency.Code { .idr }
        public static var name: String { "Rupiah" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Indonesia" }
    }
    
    /// Australian Dollar.
    public enum AUD: CurrencyType {
        public static var code: Currency.Code { .aud }
        public static var name: String { "Australian Dollar" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "Australia" }
    }
    
    /// New Zealand Dollar.
    public enum NZD: CurrencyType {
        public static var code: Currency.Code { .nzd }
        public static var name: String { "New Zealand Dollar" }
        public static var minorUnit: Int { 2 }
        public static var country: String { "New Zealand" }
    }
}
