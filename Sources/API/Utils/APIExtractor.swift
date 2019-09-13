import Foundation

///
extension IG.API {
    /// Namespace for information extractors.
    enum Extractor {}
}

extension IG.API.Extractor {
    /// Checks the given market for a currency market of "foreign exchange" type and return its base and counter currencies.
    /// - remark: Cryptocurrencies return `nil`.
    /// - parameter market: The market being introspected.
    /// - returns: `nil` if the market is not a forex market. Otherwise the proper base and counter currencies.
    static func forexCurrencies(from market: IG.API.Market) -> (base: IG.Currency.Code, counter: IG.Currency.Code)? {
        guard market.instrument.type == .currencies else { return nil }
        
        // A. The safest value is the pip meaning. However, it is not always indicated
        if let pip = market.instrument.pip?.meaning {
            // The pip meaning is divided in the meaning number and the currencies.
            let components = pip.split(separator: " ")
            if components.count > 1 {
                let codes = components[1].split(separator: "/")
                if codes.count == 2, let counter = IG.Currency.Code(rawValue: .init(codes[0])),
                   let base = IG.Currency.Code(rawValue: .init(codes[1])) {
                    return (base, counter)
                }
            }
        }
        // B. Check the market identifier
        if let marketId = market.identifier, marketId.count == 6 {
            if let base = IG.Currency.Code(rawValue: .init(marketId.prefix(3)) ),
                let counter = IG.Currency.Code(rawValue: .init(marketId.suffix(3))) {
                return (base, counter)
            }
        }
        // C. Check the epic
        let epicSplit = market.instrument.epic.rawValue.split(separator: ".")
        if epicSplit.count > 3 {
            let identifier = epicSplit[2]
            if let base = IG.Currency.Code(rawValue: .init(identifier.prefix(3)) ),
               let counter = IG.Currency.Code(rawValue: .init(identifier.suffix(3))) {
                return (base, counter)
            }
        }
        
        return nil
    }
}
