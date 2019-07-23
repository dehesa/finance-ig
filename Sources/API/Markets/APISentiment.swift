import ReactiveSwift
import Foundation

extension API.Request.Markets {
    
    // MARK: GET /clientsentiment
    
    /// Returns the client sentiment for the gven markets.
    /// - parameter marketIdentifiers: The platform's markets being targeted (don't confuse it with `epic` identifiers).
    public func getSentiment(from marketIdentifiers: [String]) -> SignalProducer<[API.Market.Sentiment],API.Error> {
        return SignalProducer(api: self.api) { (_) -> [String] in
                let filteredIds = marketIdentifiers.filter { !$0.isEmpty }
                guard !filteredIds.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "There needs to be at least one market identifier.")
                }
                return filteredIds
            }.request(.get, "clientsentiment", version: 1, credentials: true, queries: { (_, marketIds) -> [URLQueryItem] in
                [URLQueryItem(name: "marketIds", value: marketIds.joined(separator: ","))]
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: API.Request.Markets.WrapperList) in w.clientSentiments }
    }
    
    // MARK: GET /clientsentiment/{marketId}
    
    /// Returns the client sentiment for the gven market.
    /// - parameter marketIdentifier: The platform's market being targeted (don't confuse it with `epic` identifiers).
    public func getSentiment(from marketIdentifier: String) -> SignalProducer<API.Market.Sentiment,API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !marketIdentifier.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "An empty market identifier is not supported.")
                }
            }.request(.get, "clientsentiment/\(marketIdentifier)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }
    
    // MARK: GET /clientsentiment/related/{marketId}
    
    /// Returns a list of markets (and its sentiments) that are being traded the most and are related to the gven market.
    /// - parameter marketIdentifier: The platform's market being targeted (don't confuse it with `epic` identifiers).
    public func getRelated(to marketIdentifier: String) -> SignalProducer<[API.Market.Sentiment],API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !marketIdentifier.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "An empty market identifier is not supported.")
                }
            }.request(.get, "clientsentiment/related/\(marketIdentifier)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: API.Request.Markets.WrapperList) in w.clientSentiments }
    }
    
}

// MARK: - Supporting Entities

// MARK: Response Entities

extension API.Request.Markets {
    private struct WrapperList: Decodable {
        let clientSentiments: [API.Market.Sentiment]
    }
}

extension API.Market {
    /// The sentiment of all users of the platform towards a targeted market.
    public struct Sentiment: Decodable {
        /// The name of a natural grouping of a set of IG markets
        ///
        /// It typically represents the underlying 'real-world' market. For example, `VOD-UK` represents Vodafone Group PLC (UK).
        /// This identifier is primarily used in the our market research services, such as client sentiment, and may be found on the /market/{epic} service
        let marketIdentifier: String
        /// Percentage long positions (over 100%).
        let longs: Double
        /// Percentage short positions (over 100%).
        let shorts: Double
        
        private enum CodingKeys: String, CodingKey {
            case marketIdentifier = "marketId"
            case longs = "longPositionPercentage"
            case shorts = "shortPositionPercentage"
        }
    }
}

