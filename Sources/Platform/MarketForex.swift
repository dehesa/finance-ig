import Money
import Foundation

/// Conditions for a market to be Foreign Exchange Tradeable.
public protocol ForexTradable {
    /// An initializer for the Forex type given the two involved currencies.
    /// - parameter base: The base currency for the exchange.
    /// - parameter counter: The counter currency for the exchange.
    /// - parameter keepDirection: Whether the currency left/right need to be enforced or it can be swapped.
    init?(_ base: Currency.Type, _ counter: Currency.Type, keepDirection: Bool)
    /// The two currencies involved in the trading.
    var pair: Currencies.Pair { get }
}

extension ForexTradable where Self: RawRepresentable, Self.RawValue == String {
    public init?(_ base: Currency.Type, _ counter: Currency.Type, keepDirection: Bool = false) {
        let code: (base: String, counter: String) = (base.code, counter.code)
        
        if let result = Self(rawValue: code.base + code.counter) {
            self = result
        } else if !keepDirection, let result = Self(rawValue: code.counter + code.base) {
            self = result
        } else {
            return nil
        }
    }
    
    public var pair: Currencies.Pair {
        let midPoint = self.rawValue.index(self.rawValue.startIndex, offsetBy: 3)
        let baseCode = String(self.rawValue[..<midPoint])
        let counterCode = String(self.rawValue[midPoint...])
        
        guard let base = Currencies.identify(fromCode: baseCode),
            let counter = Currencies.identify(fromCode: counterCode) else {
                fatalError("A currency code couldn't be translated to a Currency type.")
        }
        
        return (base, counter)
    }
}

extension Market.Forex {
    /// Mini currency market.
    public enum Mini: String, Epic, ForexTradable {
        case AUD_CAD = "AUDCAD"
        case AUD_CHF = "AUDCHF"
        case AUD_EUR = "AUDEUR"
        case AUD_GBP = "AUDGBP"
        case AUD_JPY = "AUDJPY"
        case AUD_NZD = "AUDNZD"
        case AUD_SGD = "AUDSGD"
        case AUD_USD = "AUDUSD"
        case BRL_JPY = "BRLJPY"
        case CAD_CHF = "CADCHF"
        case CAD_JPY = "CADJPY"
        case CAD_NOK = "CADNOK"
        case CHF_NOK = "CHFNOK"
        case CHF_JPY = "CHFJPY"
        case CNH_JPY = "CNHJPY"
        case EUR_AUD = "EURAUD"
        case EUR_CAD = "EURCAD"
        case EUR_CHF = "EURCHF"
        case EUR_DKK = "EURDKK"
        case EUR_NOK = "EURNOK"
        case EUR_GBP = "EURGBP"
        case EUR_JPY = "EURJPY"
        case EUR_NZD = "EURNZD"
        case EUR_SEK = "EURSEK"
        case EUR_SGD = "EURSGD"
        case EUR_USD = "EURUSD"
        case EUR_ZAR = "EURZAR"
        case GBP_AUD = "GBPAUD"
        case GBP_CAD = "GBPCAD"
        case GBP_CHF = "GBPCHF"
        case GBP_DKK = "GBPDKK"
        case GBP_EUR = "GBPEUR"
        case GBP_INR = "GBPINR"
        case GBP_JPY = "GBPJPY"
        case GBP_NOK = "GBPNOK"
        case GBP_NZD = "GBPNZD"
        case GBP_SEK = "GBPSEK"
        case GBP_SGD = "GBPSGD"
        case GBP_USD = "GBPUSD"
        case GBP_ZAR = "GBPZAR"
        case MXN_JPY = "MXNJPY"
        case NOK_JPY = "NOKJPY"
        case NOK_SEK = "NOKSEK"
        case NZD_AUD = "NZDAUD"
        case NZD_CAD = "NZDCAD"
        case NZD_CHF = "NZDCHF"
        case NZD_EUR = "NZDEUR"
        case NZD_GBP = "NZDGBP"
        case NZD_JPY = "NZDJPY"
        case NZD_USD = "NZDUSD"
        case PLN_JPY = "PLNJPY"
        case SEK_JPY = "SEKJPY"
        case SGD_JPY = "SGDJPY"
        case USD_CAD = "USDCAD"
        case USD_CHF = "USDCHF"
        case USD_DKK = "USDDKK"
        case USD_JPY = "USDJPY"
        case USD_NOK = "USDNOK"
        case USD_SEK = "USDSEK"
        case USD_SGD = "USDSGD"
        case USD_ZAR = "USDZAR"
        
        /// The identifier prefix for all Mini forex exchange.
        private static let prefix = "CS.D."
        /// The identifier suffix for all Mini forex exchange.
        private static let suffix = ".MINI.IP"
        
        public var identifier: String {
            return Mini.prefix + self.rawValue + Mini.suffix
        }
    }
}

