import Foundation

/// Base for all monetary units
public protocol CurrencyType {
    /// Three letter code standardize by ISO 4217.
    static var code: IG.Currency.Code { get }
    /// The standard name for the currency.
    static var name: String { get }
    /// The number of decimal places used to express any minor units for the currency.
    static var minorUnit: Int { get }
}

/// Namespace for currencies.
public enum Currency {
    /// ISO 4217 currency codes.
    public enum Code: String, ExpressibleByStringLiteral, CustomStringConvertible, Hashable, Codable {
        case cad = "CAD"
        case usd = "USD"
        case mxn = "MXN"
        case brl = "BRL"
        case gbp = "GBP"
        case nok = "NOK"
        case sek = "SEK"
        case dkk = "DKK"
        case eur = "EUR"
        case chf = "CHF"
        case czk = "CZK"
        case huf = "HUF"
        case pln = "PLN"
        case rub = "RUB"
        case `try` = "TRY"
        case zar = "ZAR"
        case inr = "INR"
        case sgd = "SGD"
        case cny = "CNY"
        case twd = "TWD"
        case krw = "KRW"
        case jpy = "JPY"
        case php = "PHP"
        case idr = "IDR"
        case aud = "AUD"
        case nzd = "NZD"
        
        public init(stringLiteral value: String) {
            guard let currency = Self.init(rawValue: value) else {
                fatalError("The given string \"\(value)\" couldn't be identified as a currency")
            }
            self = currency
        }
        
        public var description: String {
            return self.rawValue
        }
    }
}

// MARK: - Currency List

// MARK: Alias

public typealias `$` = Currency.USD
public typealias € = Currency.EUR
public typealias ￥ = Currency.JPY
public typealias ￡ = Currency.EUR


// MARK: Types

extension Currency {
    /// Canadian Dollar.
    public enum CAD: CurrencyType {
        public static var code: Currency.Code { .cad }
        public static var name: String { "Canadian Dollar" }
        public static var minorUnit: Int { 2 }
    }
    
    /// United States Dollar.
    public enum USD: CurrencyType {
        public static var code: Currency.Code { .usd }
        public static var name: String { "US Dollar" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Mexican Peso.
    public enum MXN: CurrencyType {
        public static var code: Currency.Code { .mxn }
        public static var name: String { "Mexican Peso" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Brazilian Real.
    public enum BRL: CurrencyType {
        public static var code: Currency.Code { .brl }
        public static var name: String { "Brazilian Real" }
        public static var minorUnit: Int { 2 }
    }
    
    /// British Pound Sterling.
    public enum GBP: CurrencyType {
        public static var code: Currency.Code { .gbp }
        public static var name: String { "Pound Sterling" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Norwegian Krone.
    public enum NOK: CurrencyType {
        public static var code: Currency.Code { .nok }
        public static var name: String { "Norwegian Krone" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Swedish Krona.
    public enum SEK: CurrencyType {
        public static var code: Currency.Code { .sek }
        public static var name: String { "Swedish Krona" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Danish Krone.
    public enum DKK: CurrencyType {
        public static var code: Currency.Code { .dkk }
        public static var name: String { "Danish Krone" }
        public static var minorUnit: Int { 2 }
    }
    
    /// European Union Euro.
    public enum EUR: CurrencyType {
        public static var code: Currency.Code { .eur }
        public static var name: String { "Euro" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Swiss Franc.
    public enum CHF: CurrencyType {
        public static var code: Currency.Code { .chf }
        public static var name: String { "Swiss Franc" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Czech Koruna.
    public enum CZK: CurrencyType {
        public static var code: Currency.Code { .czk }
        public static var name: String { "Czech Koruna" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Hungarian Forint.
    public enum HUF: CurrencyType {
        public static var code: Currency.Code { .huf }
        public static var name: String { "Forint" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Polish Zloty.
    public enum PLN: CurrencyType {
        public static var code: Currency.Code { .pln }
        public static var name: String { "Zloty" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Russian Ruble.
    public enum RUB: CurrencyType {
        public static var code: Currency.Code { .rub }
        public static var name: String { "Russian Ruble" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Turkish Lira.
    public enum TRY: CurrencyType {
        public static var code: Currency.Code { .try }
        public static var name: String { "Turkish Lira" }
        public static var minorUnit: Int { 2 }
    }
    
    /// South African Rand.
    public enum ZAR: CurrencyType {
        public static var code: Currency.Code { .zar }
        public static var name: String { "Rand" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Indian Rupee.
    public enum INR: CurrencyType {
        public static var code: Currency.Code { .inr }
        public static var name: String { "Indian Rupee" }
        public static var minorUnit: Int { return 2 }
    }
    
    /// Singapore Dollar.
    public enum SGD: CurrencyType {
        public static var code: Currency.Code { .sgd }
        public static var name: String { "Singapore Dollar" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Chinese Yuan Renminbi
    public enum CNY: CurrencyType {
        public static var code: Currency.Code { .cny }
        public static var name: String { "Yuan Renminbi" }
        public static var minorUnit: Int { 2 }
    }
    
    /// New Taiwan Dollar.
    public enum TWD: CurrencyType {
        public static var code: Currency.Code { .twd }
        public static var name: String { "New Taiwan Dollar" }
        public static var minorUnit: Int { 2 }
    }
    
    /// South Korean Won.
    public enum KRW: CurrencyType {
        public static var code: Currency.Code { .krw }
        public static var name: String { "Won" }
        public static var minorUnit: Int { 0 }
    }
    
    /// Japanese Yen.
    public enum JPY: CurrencyType {
        public static var code: Currency.Code { .jpy }
        public static var name: String { "Yen" }
        public static var minorUnit: Int { 0 }
    }
    
    /// Philippine Piso.
    public enum PHP: CurrencyType {
        public static var code: Currency.Code { .php }
        public static var name: String { "Philippine Piso" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Indonesian Rupiah.
    public enum IDR: CurrencyType {
        public static var code: Currency.Code { .idr }
        public static var name: String { "Rupiah" }
        public static var minorUnit: Int { 2 }
    }
    
    /// Australian Dollar.
    public enum AUD: CurrencyType {
        public static var code: Currency.Code { .aud }
        public static var name: String { "Australian Dollar" }
        public static var minorUnit: Int { 2 }
    }
    
    /// New Zealand Dollar.
    public enum NZD: CurrencyType {
        public static var code: Currency.Code { .nzd }
        public static var name: String { "New Zealand Dollar" }
        public static var minorUnit: Int { 2 }
    }
}
