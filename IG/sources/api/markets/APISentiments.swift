import Combine
import Decimals

extension API.Request.Markets {
    
    // MARK: GET /clientsentiment
    
    /// Returns the client sentiment for the gven markets.
    /// - parameter marketIdentifiers: The platform's markets being targeted (don't confuse it with `epic` identifiers).
    /// - returns: Publisher forwarding  a list of all targeted markets along with their short/long sentiments.
    public func getSentiment(from marketIdentifiers: [String]) -> AnyPublisher<[API.Market.Sentiment],IG.Error> {
        self.api.publisher { _ -> [String] in
                let filteredIds = marketIdentifiers.filter { !$0.isEmpty }
                guard !filteredIds.isEmpty else {
                    throw IG.Error(.api(.invalidRequest), "There were no market identifiers to query.", help: "Input at least one (non-empty) market identifier.")
                }
                return filteredIds
            }.makeRequest(.get, "clientsentiment", version: 1, credentials: true, queries: {
                [.init(name: "marketIds", value: $0.joined(separator: ","))]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperList, _) in w.clientSentiments }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /clientsentiment/{marketId}
    
    /// Returns the client sentiment for the gven market.
    /// - parameter marketIdentifier: The platform's market being targeted (don't confuse it with `epic` identifiers).
    /// - returns: Publisher forwarding  a market's short/long sentiments.
    public func getSentiment(from marketIdentifier: String) -> AnyPublisher<API.Market.Sentiment,IG.Error> {
        self.api.publisher { _ in
                guard !marketIdentifier.isEmpty else {
                    throw IG.Error(.api(.invalidRequest), "The watchlist identifier cannot be empty.", help: "Empty strings are not valid identifiers. Query the watchlist endpoint again and retrieve a proper watchlist identifier.")
                }
            }.makeRequest(.get, "clientsentiment/\(marketIdentifier)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /clientsentiment/related/{marketId}
    
    /// Returns a list of markets (and its sentiments) that are being traded the most and are related to the gven market.
    /// - parameter marketIdentifier: The platform's market being targeted (don't confuse it with `epic` identifiers).
    /// - returns: Publisher forwarding a list of markets related to the given market along with their short/long sentiments.
    public func getSentiment(relatedTo marketIdentifier: String) -> AnyPublisher<[API.Market.Sentiment],IG.Error> {
        self.api.publisher { _ in
                guard !marketIdentifier.isEmpty else {
                    throw IG.Error(.api(.invalidRequest), "The watchlist identifier cannot be empty.", help: "Empty strings are not valid identifiers. Query the watchlist endpoint again and retrieve a proper watchlist identifier.")
                }
            }.makeRequest(.get, "clientsentiment/related/\(marketIdentifier)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperList, _) in w.clientSentiments }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
}

// MARK: - Request Entities

extension API.Request.Markets {
    private struct _WrapperList: Decodable {
        let clientSentiments: [API.Market.Sentiment]
    }
}
