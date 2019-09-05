import ReactiveSwift
import Foundation

extension IG.API.Request.Markets {
    
    // MARK: GET /clientsentiment
    
    /// Returns the client sentiment for the gven markets.
    /// - parameter marketIdentifiers: The platform's markets being targeted (don't confuse it with `epic` identifiers).
    public func getSentiment(from marketIdentifiers: [String]) -> SignalProducer<[IG.API.Market.Sentiment],IG.API.Error> {
        return SignalProducer(api: self.api) { (_) -> [String] in
                let filteredIds = marketIdentifiers.filter { !$0.isEmpty }
                guard !filteredIds.isEmpty else {
                    let message = "There were no market identifiers to query"
                    let suggestion = "Input at least one (non-empty) market identifier"
                    throw IG.API.Error.invalidRequest(message, suggestion: suggestion)
                }
                return filteredIds
            }.request(.get, "clientsentiment", version: 1, credentials: true, queries: { (_, marketIds) -> [URLQueryItem] in
                [URLQueryItem(name: "marketIds", value: marketIds.joined(separator: ","))]
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperList) in w.clientSentiments }
    }
    
    // MARK: GET /clientsentiment/{marketId}
    
    /// Returns the client sentiment for the gven market.
    /// - parameter marketIdentifier: The platform's market being targeted (don't confuse it with `epic` identifiers).
    public func getSentiment(from marketIdentifier: String) -> SignalProducer<IG.API.Market.Sentiment,IG.API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !marketIdentifier.isEmpty else {
                    let message = "There market identifier provided contained no characters"
                    let suggestion = "Input a valid market identifier"
                    throw IG.API.Error.invalidRequest(message, suggestion: suggestion)
                }
            }.request(.get, "clientsentiment/\(marketIdentifier)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }
    
    // MARK: GET /clientsentiment/related/{marketId}
    
    /// Returns a list of markets (and its sentiments) that are being traded the most and are related to the gven market.
    /// - parameter marketIdentifier: The platform's market being targeted (don't confuse it with `epic` identifiers).
    public func getSentimentRelated(to marketIdentifier: String) -> SignalProducer<[IG.API.Market.Sentiment],IG.API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !marketIdentifier.isEmpty else {
                    let message = "There market identifier provided contained no characters"
                    let suggestion = "Input a valid market identifier"
                    throw IG.API.Error.invalidRequest(message, suggestion: suggestion)
            }
            }.request(.get, "clientsentiment/related/\(marketIdentifier)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperList) in w.clientSentiments }
    }
    
}

// MARK: - Supporting Entities

// MARK: Response Entities

extension IG.API.Request.Markets {
    private struct WrapperList: Decodable {
        let clientSentiments: [IG.API.Market.Sentiment]
    }
}

extension IG.API.Market {
    /// The sentiment of all users of the platform towards a targeted market.
    public struct Sentiment: Decodable {
        /// The name of a natural grouping of a set of IG markets
        ///
        /// It typically represents the underlying 'real-world' market. For example, `VOD-UK` represents Vodafone Group PLC (UK).
        /// This identifier is primarily used in the our market research services, such as client sentiment, and may be found on the /market/{epic} service
        public let marketIdentifier: String
        /// Percentage long positions (over 100%).
        public let longs: Decimal
        /// Percentage short positions (over 100%).
        public let shorts: Decimal
        
        private enum CodingKeys: String, CodingKey {
            case marketIdentifier = "marketId"
            case longs = "longPositionPercentage"
            case shorts = "shortPositionPercentage"
        }
    }
}

extension IG.API.Market.Sentiment: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = IG.DebugDescription("API Market Sentiment")
        result.append("market ID", self.marketIdentifier)
        result.append("longs", "\(self.longs) %")
        result.append("shorts", "\(self.shorts) %")
        return result.generate()
    }
}
