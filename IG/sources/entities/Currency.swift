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
    public enum Code: ExpressibleByStringLiteral, LosslessStringConvertible, Hashable, Comparable {
        /// Canadian Dollar.
        case cad
        /// United States Dollar.
        case usd
        /// Mexican Peso.
        case mxn
        /// Brazilian Real.
        case brl
        /// British Pound Sterling.
        case gbp
        /// Norwegian Krone.
        case nok
        /// Swedish Krona.
        case sek
        /// Danish Krone.
        case dkk
        /// European Union Euro.
        case eur
        /// Swiss Franc.
        case chf
        /// Czech Koruna.
        case czk
        /// Hungarian Forint.
        case huf
        /// Polish Zloty.
        case pln
        /// Russian Ruble.
        case rub
        /// Turkish Lira.
        case `try`
        /// South African Rand.
        case zar
        /// Indian Rupee.
        case inr
        /// Singapore Dollar.
        case sgd
        /// Chinese Yuan Renminbi
        case cny
        /// Hong Kong Dollar
        case hkd
        /// New Taiwan Dollar.
        case twd
        /// South Korean Won.
        case krw
        /// Japanese Yen.
        case jpy
        /// Philippine Piso.
        case php
        /// Indonesian Rupiah.
        case idr
        /// Australian Dollar.
        case aud
        /// New Zealand Dollar.
        case nzd
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

// MARK: -

/// ISO 4217 currency codes.
extension Currency.Code: Codable {
    public init?(_ description: String) {
        guard description.utf8.count == 3 else { return nil }
        
        switch description {
        case _Values.cad: self = .cad
        case _Values.usd: self = .usd
        case _Values.mxn: self = .mxn
        case _Values.brl: self = .brl
        case _Values.gbp: self = .gbp
        case _Values.nok: self = .nok
        case _Values.sek: self = .sek
        case _Values.dkk: self = .dkk
        case _Values.eur: self = .eur
        case _Values.chf: self = .chf
        case _Values.czk: self = .czk
        case _Values.huf: self = .huf
        case _Values.pln: self = .pln
        case _Values.rub: self = .rub
        case _Values.try, _Values.trl: self = .try
        case _Values.zar: self = .zar
        case _Values.inr: self = .inr
        case _Values.sgd: self = .sgd
        case _Values.cny, _Values.cnh: self = .cny
        case _Values.hkd: self = .hkd
        case _Values.twd: self = .twd
        case _Values.krw: self = .krw
        case _Values.jpy: self = .jpy
        case _Values.php: self = .php
        case _Values.idr: self = .idr
        case _Values.aud: self = .aud
        case _Values.nzd: self = .nzd
        default: return nil
        }
    }
    
    public init(stringLiteral value: String) {
        let currency = Self.init(value) ?! fatalError("Invalid currency code '\(value)'.")
        self = currency
    }
    
    public var description: String {
        switch self {
        case .cad: return _Values.cad
        case .usd: return _Values.usd
        case .mxn: return _Values.mxn
        case .brl: return _Values.brl
        case .gbp: return _Values.gbp
        case .nok: return _Values.nok
        case .sek: return _Values.sek
        case .dkk: return _Values.dkk
        case .eur: return _Values.eur
        case .chf: return _Values.chf
        case .czk: return _Values.czk
        case .huf: return _Values.huf
        case .pln: return _Values.pln
        case .rub: return _Values.rub
        case .try: return _Values.try
        case .zar: return _Values.zar
        case .inr: return _Values.inr
        case .sgd: return _Values.sgd
        case .cny: return _Values.cny
        case .hkd: return _Values.hkd
        case .twd: return _Values.twd
        case .krw: return _Values.krw
        case .jpy: return _Values.jpy
        case .php: return _Values.php
        case .idr: return _Values.idr
        case .aud: return _Values.aud
        case .nzd: return _Values.nzd
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = try Self.init(value) ?> DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid currency code '\(value)'.")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
    
    @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.description < rhs.description
    }
    
    private enum _Values {
        static var cad: String { "CAD" }
        static var usd: String { "USD" }
        static var mxn: String { "MXN" }
        static var brl: String { "BRL" }
        static var gbp: String { "GBP" }
        static var nok: String { "NOK" }
        static var sek: String { "SEK" }
        static var dkk: String { "DKK" }
        static var eur: String { "EUR" }
        static var chf: String { "CHF" }
        static var czk: String { "CZK" }
        static var huf: String { "HUF" }
        static var pln: String { "PLN" }
        static var rub: String { "RUB" }
        static var `try`: String { "TRY" }
        static var trl: String { "TRL" }
        static var zar: String { "ZAR" }
        static var inr: String { "INR" }
        static var sgd: String { "SGD" }
        static var cny: String { "CNY" }
        static var cnh: String { "CNH" }
        static var hkd: String { "HKD" }
        static var twd: String { "TWD" }
        static var krw: String { "KRW" }
        static var jpy: String { "JPY" }
        static var php: String { "PHP" }
        static var idr: String { "IDR" }
        static var aud: String { "AUD" }
        static var nzd: String { "NZD" }
    }
}
