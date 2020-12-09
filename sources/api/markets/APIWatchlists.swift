import Combine
import Foundation

extension API.Request {
    /// List of endpoints related to API watchlists.
    @frozen public struct Watchlists {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        private unowned let _api: API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        @usableFromInline internal init(api: API) { self._api = api }
    }
}

extension API.Request.Watchlists {
    /// Creates a watchlist.
    /// - seealso: POST /watchlists
    /// - parameter name: Watchlist given name.
    /// - parameter epics: List of market epics to be associated to this new watchlist.
    /// - returns: Publisher forwarding the identifier of the created watchlist and a Boolean indicating whether the all epics where added to the watchlist).
    public func create(name: String, epics: [IG.Market.Epic]) -> AnyPublisher<(identifier: String, areAllInstrumentsAdded: Bool),IG.Error> {
        self._api.publisher { _ -> _PayloadCreation in
                guard !name.isEmpty else { throw IG.Error._emptyWatchlistIdentifier() }
                return .init(name: name, epics: epics.uniqueElements)
            }.makeRequest(.post, "watchlists", version: 1, credentials: true, body: {
                (.json, try JSONEncoder().encode($0))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperCreation, _) in (w.id, w.areAllInstrumentsAdded) }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Returns all watchlists belonging to the active account.
    /// - seealso: GET /watchlists
    /// - returns: Publisher forwarding an array of watchlists.
    public func getAll() -> AnyPublisher<[API.Watchlist],IG.Error> {
        self._api.publisher
            .makeRequest(.get, "watchlists", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperList, _) in w.watchlists }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Returns the targeted watchlist.
    /// - seealso: GET /watchlists/{watchlistId}
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - returns: Publisher forwarding all markets under the targeted watchlist.
    public func getMarkets(from identifier: String) -> AnyPublisher<[API.Node.Market],IG.Error> {
        self._api.publisher { _ -> Void in
                guard !identifier.isEmpty else { throw IG.Error._emptyWatchlistIdentifier() }
            }.makeRequest(.get, "watchlists/\(identifier)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(date: true)) { (w: _WrapperWatchlist, _) in w.markets }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Adds a market to a watchlist.
    /// - seealso: PUT /watchlists/{watchlistId}
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be added to the watchlist.
    /// - returns: Publisher indicating the success of the operation.
    public func update(identifier: String, addingEpic epic: IG.Market.Epic) -> AnyPublisher<Never,IG.Error> {
        self._api.publisher { _ in guard !identifier.isEmpty else { throw IG.Error._emptyWatchlistIdentifier() } }
            .makeRequest(.put, "watchlists/\(identifier)", version: 1, credentials: true, body: { (.json, try JSONEncoder().encode(["epic": epic])) })
            .send(expecting: .json, statusCode: 200)
            //.decodeJSON(decoder: .default()) { (_: Self.WrapperUpdate, _) in return }
            .ignoreOutput()
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Removes a market from a watchlist.
    /// - seealso: DELETE /watchlists/{watchlistId}/{epic}
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be removed from the watchlist.
    /// - returns: Publisher indicating the success of the operation.
    public func update(identifier: String, removingEpic epic: IG.Market.Epic) -> AnyPublisher<Never,IG.Error> {
        self._api.publisher { _ in guard !identifier.isEmpty else { throw IG.Error._emptyWatchlistIdentifier() } }
            .makeRequest(.delete, "watchlists/\(identifier)/\(epic)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            //.decodeJSON(decoder: .default()) { (_: Self.WrapperUpdate, _) in return }
            .ignoreOutput()
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Deletes the targeted watchlist.
    /// - seealso: DELETE /watchlists/{watchlistId}
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - returns: Publisher indicating the success of the operation.
    public func delete(identifier: String) -> AnyPublisher<Never,IG.Error> {
        self._api.publisher { _ in guard !identifier.isEmpty else { throw IG.Error._emptyWatchlistIdentifier() } }
            .makeRequest(.delete, "watchlists/\(identifier)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            //.decodeJSON(decoder: .default()) { (w: Self.WrapperUpdate, _) in return }
            .ignoreOutput()
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

private extension API.Request.Watchlists {
    struct _PayloadCreation: Encodable {
        let name: String
        let epics: [IG.Market.Epic]
    }
}

// MARK: Response Entities

private extension API.Request.Watchlists {
    struct _WrapperCreation: Identifiable, Decodable {
        let id: String
        let areAllInstrumentsAdded: Bool

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.id = try container.decode(String.self, forKey: .id)
            let status = try container.decode(CodingKeys._Status.self, forKey: .status)
            self.areAllInstrumentsAdded = (status == .success)
        }

        private enum CodingKeys: String, CodingKey {
            case id = "watchlistId"
            case status = "status"
            
            enum _Status: String, Decodable {
                case success = "SUCCESS"
                case notAllInstrumentAdded = "SUCCESS_NOT_ALL_INSTRUMENTS_ADDED"
            }
        }
    }
    
    struct _WrapperWatchlist: Decodable {
        let markets: [API.Node.Market]
    }
    
    struct _WrapperList: Decodable {
        let watchlists: [API.Watchlist]
    }
    
    struct _WrapperUpdate: Decodable {
        let status: Self._Status
        
        enum _Status: String, Decodable {
            case success = "SUCCESS"
        }
    }
}

private extension IG.Error {
    /// Error raised when the request define an empty watchlist identifier.
    static func _emptyWatchlistIdentifier() -> Self {
        Self(.api(.invalidRequest), "The watchlist identifier cannot be empty.", help: "Empty strings are not valid identifiers. Query the endpoint again and retrieve a proper watchlist identifier.")
    }
}
