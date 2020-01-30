import Combine
import Foundation

extension IG.API.Request {
    /// List of endpoints related to API watchlists.
    public struct Watchlists {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        fileprivate unowned let api: IG.API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        init(api: IG.API) { self.api = api }
    }
}

extension IG.API.Request.Watchlists {
    
    // MARK: POST /watchlists
    
    /// Creates a watchlist.
    /// - parameter name: Watchlist given name.
    /// - parameter epics: List of market epics to be associated to this new watchlist.
    /// - returns: *Future* forwarding the identifier of the created watchlist and a Boolean indicating whether the all epics where added to the watchlist).
    public func create(name: String, epics: [IG.Market.Epic]) -> IG.API.Publishers.Discrete<(identifier: String, areAllInstrumentsAdded: Bool)> {
        self.api.publisher { _ -> Self.PayloadCreation in
                guard !name.isEmpty else {
                    throw IG.API.Error.invalidRequest("The watchlist name cannot be empty", suggestion: "The watchlist name must contain at least one character")
                }
                return .init(name: name, epics: epics.uniqueElements)
            }.makeRequest(.post, "watchlists", version: 1, credentials: true, body: {
                (.json, try JSONEncoder().encode($0))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: Self.WrapperCreation, _) in (w.identifier, w.areAllInstrumentsAdded) }
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }

    
    // MARK: GET /watchlists
    
    /// Returns all watchlists belonging to the active account.
    /// - returns: *Future* forwarding an array of watchlists.
    public func getAll() -> IG.API.Publishers.Discrete<[IG.API.Watchlist]> {
        self.api.publisher
            .makeRequest(.get, "watchlists", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: Self.WrapperList, _) in w.watchlists }
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK: GET /watchlists/{watchlistId}
    
    /// Returns the targeted watchlist.
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - returns: *Future* forwarding all markets under the targeted watchlist.
    public func getMarkets(from identifier: String) -> IG.API.Publishers.Discrete<[IG.API.Node.Market]> {
        self.api.publisher { _ -> Void in
                guard !identifier.isEmpty else {
                    throw IG.API.Error.invalidRequest(IG.API.Error.Message.emptyWatchlistIdentifier, suggestion: IG.API.Error.Suggestion.emptyWatchlistIdentifier)
                }
            }.makeRequest(.get, "watchlists/\(identifier)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(date: true)) { (w: Self.WrapperWatchlist, _) in w.markets }
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK: PUT /watchlists/{watchlistId}
    
    /// Adds a market to a watchlist.
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be added to the watchlist.
    /// - returns: *Future* indicating the success of the operation.
    public func update(identifier: String, addingEpic epic: IG.Market.Epic) -> IG.API.Publishers.Discrete<Never> {
        self.api.publisher { _ in
                guard !identifier.isEmpty else {
                    throw IG.API.Error.invalidRequest(.emptyWatchlistIdentifier, suggestion: .emptyWatchlistIdentifier)
                }
            }.makeRequest(.put, "watchlists/\(identifier)", version: 1, credentials: true, body: {
                (.json, try JSONEncoder().encode(["epic": epic]))
            }).send(expecting: .json, statusCode: 200)
            //.decodeJSON(decoder: .default()) { (_: Self.WrapperUpdate, _) in return }
            .ignoreOutput()
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }

    
    // MARK: DELETE /watchlists/{watchlistId}/{epic}
    
    /// Removes a market from a watchlist.
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be removed from the watchlist.
    /// - returns: *Future* indicating the success of the operation.
    public func update(identifier: String, removingEpic epic: IG.Market.Epic) -> IG.API.Publishers.Discrete<Never> {
        self.api.publisher { _ in
                guard !identifier.isEmpty else {
                    throw IG.API.Error.invalidRequest(.emptyWatchlistIdentifier, suggestion: .emptyWatchlistIdentifier)
                }
            }.makeRequest(.delete, "watchlists/\(identifier)/\(epic.rawValue)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            //.decodeJSON(decoder: .default()) { (_: Self.WrapperUpdate, _) in return }
            .ignoreOutput()
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK: DELETE /watchlists/{watchlistId}
    
    /// Deletes the targeted watchlist.
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - returns: *Future* indicating the success of the operation.
    public func delete(identifier: String) -> IG.API.Publishers.Discrete<Never> {
        self.api.publisher { _ in
                guard !identifier.isEmpty else {
                    throw IG.API.Error.invalidRequest(.emptyWatchlistIdentifier, suggestion: .emptyWatchlistIdentifier)
                }
            }.makeRequest(.delete, "watchlists/\(identifier)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            //.decodeJSON(decoder: .default()) { (w: Self.WrapperUpdate, _) in return }
            .ignoreOutput()
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.API.Request.Watchlists {
    private struct PayloadCreation: Encodable {
        let name: String
        let epics: [IG.Market.Epic]
    }
}

extension IG.API.Request.Watchlists {
    private struct WrapperCreation: Decodable {
        let identifier: String
        let areAllInstrumentsAdded: Bool

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.identifier = try container.decode(String.self, forKey: .identifier)
            let status = try container.decode(CodingKeys.Status.self, forKey: .status)
            self.areAllInstrumentsAdded = (status == .success)
        }

        private enum CodingKeys: String, CodingKey {
            case identifier = "watchlistId"
            case status = "status"
            
            enum Status: String, Decodable {
                case success = "SUCCESS"
                case notAllInstrumentAdded = "SUCCESS_NOT_ALL_INSTRUMENTS_ADDED"
            }
        }
    }
    
    private struct WrapperWatchlist: Decodable {
        let markets: [IG.API.Node.Market]
    }
    
    private struct WrapperList: Decodable {
        let watchlists: [IG.API.Watchlist]
    }
    
    private struct WrapperUpdate: Decodable {
        let status: Self.Status
        
        enum Status: String, Decodable {
            case success = "SUCCESS"
        }
    }
}

extension IG.API {
    /// Watchlist data.
    public struct Watchlist: Decodable {
        /// Watchlist identifier.
        public let identifier: String
        /// Watchlist given name.
        public let name: String
        /// Indicates whether the watchlist belong to the user or is one predefined by the system.
        public let isOwnedBySystem: Bool
        /// Indicates whether the watchlist can be altered by the user.
        public let isEditable: Bool
        /// Indicates whether the watchlist can be deleted by the user.
        public let isDeleteable: Bool

        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }

        private enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case name
            case isOwnedBySystem = "defaultSystemWatchlist"
            case isEditable = "editable"
            case isDeleteable = "deleteable"
        }
    }
}

// MARK: - Functionality

extension IG.API.Error.Message {
    fileprivate static var emptyWatchlistIdentifier: Self { "The watchlist identifier cannot be empty" }
}

extension IG.API.Error.Suggestion {
    fileprivate static var emptyWatchlistIdentifier: Self { "Empty strings are not valid identifiers. Query the watchlist endpoint again and retrieve a proper watchlist identifier" }
}

extension IG.API.Watchlist: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("watchlist ID", self.identifier)
        result.append("name", self.name)
        result.append("owned by user", !self.isOwnedBySystem)
        result.append("editable", self.isEditable)
        result.append("deleteable", self.isDeleteable)
        return result.generate()
    }
}
