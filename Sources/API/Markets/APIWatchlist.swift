import ReactiveSwift
import Foundation

extension IG.API.Request.Watchlists {
    
    // MARK: POST /watchlists
    
    /// Creates a watchlist.
    /// - parameter name: Watchlist given name.
    /// - parameter epics: List of market epics to be associated to this new watchlist.
    /// - returns: SignalProducer with the watchlist identifier as its value.
    public func create(name: String, epics: [IG.Market.Epic]) -> SignalProducer<(identifier: String, areAllInstrumentsAdded: Bool),IG.API.Error> {
        return SignalProducer(api: self.api) { (_) -> Self.PayloadCreation in
                guard !name.isEmpty else {
                    let message = "The watchlist name cannot be empty"
                    throw IG.API.Error.invalidRequest(message, suggestion: "The watchlist name must contain at least one character.")
                }
                return .init(name: name, epics: epics.uniqueElements)
            }.request(.post, "watchlists", version: 1, credentials: true, body: { (_, payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperCreation) in (w.identifier, w.areAllInstrumentsAdded) }
    }

    
    // MARK: GET /watchlists
    
    /// Returns all watchlists belonging to the active account.
    public func getAll() -> SignalProducer<[IG.API.Watchlist],IG.API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "watchlists", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperList) in w.watchlists }
    }
    
    // MARK: GET /watchlists/{watchlistId}
    
    /// Returns the targeted watchlist.
    /// - parameter identifier: The identifier for the watchlist being targeted.
    public func getMarkets(from identifier: String) -> SignalProducer<[IG.API.Node.Market],IG.API.Error> {
        return SignalProducer(api: self.api) { (_) -> Void in
                guard !identifier.isEmpty else {
                    throw IG.API.Error.invalidRequest(IG.API.Error.Message.emptyWatchlistIdentifier, suggestion: IG.API.Error.Suggestion.emptyWatchlistIdentifier)
                }
            }.request(.get, "watchlists/\(identifier)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperWatchlist) in w.markets }
    }
    
    // MARK: PUT /watchlists/{watchlistId}
    
    /// Adds a market to a watchlist.
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be added to the watchlist.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func update(identifier: String, addingEpic epic: IG.Market.Epic) -> SignalProducer<Void,IG.API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !identifier.isEmpty else {
                    throw IG.API.Error.invalidRequest(IG.API.Error.Message.emptyWatchlistIdentifier, suggestion: IG.API.Error.Suggestion.emptyWatchlistIdentifier)
                }
            }.request(.put, "watchlists/\(identifier)", version: 1, credentials: true, body: { (_,_) in
                let payload = ["epic": epic]
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (_: Self.WrapperUpdate) in return }
    }

    
    // MARK: DELETE /watchlists/{watchlistId}/{epic}
    
    /// Removes a market from a watchlist.
    /// - parameter identifier: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be removed from the watchlist.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func update(identifier: String, removingEpic epic: IG.Market.Epic) -> SignalProducer<Void,IG.API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !identifier.isEmpty else {
                    throw IG.API.Error.invalidRequest(IG.API.Error.Message.emptyWatchlistIdentifier, suggestion: IG.API.Error.Suggestion.emptyWatchlistIdentifier)
                }
            }.request(.delete, "watchlists/\(identifier)/\(epic.rawValue)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (_: Self.WrapperUpdate) in return }
    }
    
    // MARK: DELETE /watchlists/{watchlistId}
    
    /// Deletes the targeted watchlist.
    /// - parameter id: The identifier for the watchlist being targeted.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func delete(identifier watchlistIdentifier: String) -> SignalProducer<Void,IG.API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !watchlistIdentifier.isEmpty else {
                    throw IG.API.Error.invalidRequest(IG.API.Error.Message.emptyWatchlistIdentifier, suggestion: IG.API.Error.Suggestion.emptyWatchlistIdentifier)
                }
            }.request(.delete, "watchlists/\(watchlistIdentifier)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperUpdate) in return }
    }
}

// MARK: - Supporting Entities

extension IG.API.Request {
    /// Contains all functionality related to API watchlists.
    public struct Watchlists {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        fileprivate unowned let api: IG.API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        init(api: IG.API) {
            self.api = api
        }
    }
}

// MARK: Request Entities

extension IG.API.Error.Message {
    fileprivate static var emptyWatchlistIdentifier: String { "The watchlist identifier cannot be empty" }
}

extension IG.API.Error.Suggestion {
    fileprivate static var emptyWatchlistIdentifier: String { "Empty strings are not valid identifiers. Query the watchlist endpoint again and retrieve a proper watchlist identifier." }
}

extension IG.API.Request.Watchlists {
    private struct PayloadCreation: Encodable {
        let name: String
        let epics: [IG.Market.Epic]
    }
}

// MARK: Response Entities

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

extension IG.API.Watchlist: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = IG.DebugDescription("API Watchlist")
        result.append("watchlist ID", self.identifier)
        result.append("name", self.name)
        result.append("is owned by user", !self.isOwnedBySystem)
        result.append("is editable", self.isEditable)
        result.append("is deleteable", self.isDeleteable)
        return result.generate()
    }
}
