import Combine
import Decimals

extension API.Request.Markets {
    
    // MARK: GET /clientsentiment
    
    /// Returns the client sentiment for the gven markets.
    /// - parameter marketIdentifiers: The platform's markets being targeted (don't confuse it with `epic` identifiers).
    /// - returns: *Future* forwarding  a list of all targeted markets along with their short/long sentiments.
    public func getSentiment(from marketIdentifiers: [String]) -> AnyPublisher<[API.Market.Sentiment],API.Error> {
        self.api.publisher { _ -> [String] in
                let filteredIds = marketIdentifiers.filter { !$0.isEmpty }
                guard !filteredIds.isEmpty else {
                    let message = "There were no market identifiers to query"
                    let suggestion = "Input at least one (non-empty) market identifier"
                    throw API.Error.invalidRequest(.init(message), suggestion: .init(suggestion))
                }
                return filteredIds
            }.makeRequest(.get, "clientsentiment", version: 1, credentials: true, queries: {
                [.init(name: "marketIds", value: $0.joined(separator: ","))]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperList, _) in w.clientSentiments }
            .mapError(API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /clientsentiment/{marketId}
    
    /// Returns the client sentiment for the gven market.
    /// - parameter marketIdentifier: The platform's market being targeted (don't confuse it with `epic` identifiers).
    /// - returns: *Future* forwarding  a market's short/long sentiments.
    public func getSentiment(from marketIdentifier: String) -> AnyPublisher<API.Market.Sentiment,API.Error> {
        self.api.publisher { _ in
                guard !marketIdentifier.isEmpty else {
                    throw API.Error.invalidRequest(._noCharacters, suggestion: ._validMarketID)
                }
            }.makeRequest(.get, "clientsentiment/\(marketIdentifier)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /clientsentiment/related/{marketId}
    
    /// Returns a list of markets (and its sentiments) that are being traded the most and are related to the gven market.
    /// - parameter marketIdentifier: The platform's market being targeted (don't confuse it with `epic` identifiers).
    /// - returns: *Future* forwarding a list of markets related to the given market along with their short/long sentiments.
    public func getSentiment(relatedTo marketIdentifier: String) -> AnyPublisher<[API.Market.Sentiment],API.Error> {
        self.api.publisher { _ in
                guard !marketIdentifier.isEmpty else {
                    throw API.Error.invalidRequest(._noCharacters, suggestion: ._validMarketID)
                }
            }.makeRequest(.get, "clientsentiment/related/\(marketIdentifier)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperList, _) in w.clientSentiments }
            .mapError(API.Error.transform)
            .eraseToAnyPublisher()
    }
    
}

// MARK: - Entities

extension API.Request.Markets {
    private struct _WrapperList: Decodable {
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
        public let marketIdentifier: String
        /// Percentage long positions (over 100%).
        public let longs: Decimal64
        /// Percentage short positions (over 100%).
        public let shorts: Decimal64
        
        private enum CodingKeys: String, CodingKey {
            case marketIdentifier = "marketId"
            case longs = "longPositionPercentage"
            case shorts = "shortPositionPercentage"
        }
    }
}

// MARK: - Functionality

fileprivate extension API.Error.Message {
    static var _noCharacters: Self { "The watchlist identifier cannot be empty" }
}

fileprivate extension API.Error.Suggestion {
    static var _validMarketID: Self { "Empty strings are not valid identifiers. Query the watchlist endpoint again and retrieve a proper watchlist identifier" }
}

extension API.Market.Sentiment: IG.DebugDescriptable {
    internal static var printableDomain: String { "\(API.self).\(Self.self)" }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("market ID", self.marketIdentifier)
        result.append("longs", "\(self.longs) %")
        result.append("shorts", "\(self.shorts) %")
        return result.generate()
    }
}
