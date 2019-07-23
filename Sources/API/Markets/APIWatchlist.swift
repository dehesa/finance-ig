import ReactiveSwift
import Foundation

extension API.Request.Watchlists {
    
    // MARK: POST /watchlists
    
    /// Creates a watchlist.
    /// - parameter name: Watchlist given name.
    /// - parameter epics: List of market epics to be associated to this new watchlist.
    /// - returns: SignalProducer with the watchlist identifier as its value.
    public func create(name: String, epics: [String]) -> SignalProducer<(identifier: String, areAllInstrumentsAdded: Bool),API.Error> {
        return SignalProducer(api: self.api) { (_) -> API.Request.Watchlists.PayloadCreation in
                guard !name.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist creation failed! The watchlist name cannot be empty.")
                }
                let filteredEpics = epics.filter { !$0.isEmpty }
                return .init(name: name, epics: filteredEpics)
            }.request(.post, "watchlists", version: 1, credentials: true, body: { (_, payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: API.Request.Watchlists.ResponseCreation) in (w.identifier, w.areAllInstrumentsAdded) }
    }

    
    // MARK: GET /watchlists
    
    /// Returns all watchlists belonging to the active account.
    public func getAll() -> SignalProducer<[API.Watchlist],API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "watchlists", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: API.Request.Watchlists.WrapperList) in w.watchlists }
    }
    
    // MARK: GET /watchlists/{watchlistId}
    
    /// Returns the targeted watchlist.
    /// - parameter id: The identifier for the watchlist being targeted.
    public func get(identifier: String) -> SignalProducer<[API.Node.Market],API.Error> {
        return SignalProducer(api: self.api) { (_) -> Void in
                guard !identifier.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist retrieval failed! The watchlist identifier cannot be empty.")
                }
            }.request(.get, "watchlists/\(identifier)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: API.Request.Watchlists.Wrapper) in w.markets }
    }
    
    // MARK: PUT /watchlists/{watchlistId}
    
    /// Adds a market to a watchlist.
    /// - parameter watchlistIdentifier: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be added to the watchlist.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func update(identifier watchlistIdentifier: String, addingEpic epic: String) -> SignalProducer<Void,API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !watchlistIdentifier.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist update failed! The watchlist identifier cannot be empty.")
                }
                guard !epic.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist update failed! The epic to be added cannot be empty.")
                }
            }.request(.put, "watchlists/\(watchlistIdentifier)", version: 1, credentials: true, body: { (_,_) in
                let payload = ["epic": epic]
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (_: API.Request.Watchlists.WrapperUpdate) in return }
    }

    
    // MARK: DELETE /watchlists/{watchlistId}/{epic}
    
    /// Removes a market from a watchlist.
    /// - parameter watchlistIdentifier: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be removed from the watchlist.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func update(identifier watchlistIdentifier: String, removingEpic epic: String) -> SignalProducer<Void,API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !watchlistIdentifier.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist update failed! The watchlist identifier cannot be empty.")
                }
                guard !epic.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist update failed! The epic to be added cannot be empty.")
                }
            }.request(.delete, "watchlists/\(watchlistIdentifier)/\(epic)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (_: API.Request.Watchlists.WrapperUpdate) in return }
    }
    
    // MARK: DELETE /watchlists/{watchlistId}
    
    /// Deletes the targeted watchlist.
    /// - parameter id: The identifier for the watchlist being targeted.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func delete(identifier watchlistIdentifier: String) -> SignalProducer<Void,API.Error> {
        return SignalProducer(api: self.api) { _ in
                guard !watchlistIdentifier.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist deletion failed! The watchlist identifier cannot be empty.")
                }
            }.request(.delete, "watchlists/\(watchlistIdentifier)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: API.Request.Watchlists.WrapperUpdate) in return }
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to API watchlists.
    public struct Watchlists {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        fileprivate unowned let api: API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        init(api: API) {
            self.api = api
        }
    }
}

// MARK: - Request Entities

extension API.Request.Watchlists {
    private struct PayloadCreation: Encodable {
        let name: String
        let epics: [String]
    }
}

// MARK: - Response Entities

extension API.Request.Watchlists {
    private struct ResponseCreation: Decodable {
        let identifier: String
        let areAllInstrumentsAdded: Bool

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
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
    
    private struct Wrapper: Decodable {
        let markets: [API.Node.Market]
    }
    
    private struct WrapperList: Decodable {
        let watchlists: [API.Watchlist]
    }
    
    private struct WrapperUpdate: Decodable {
        let status: Status
        
        enum Status: String, Decodable {
            case success = "SUCCESS"
        }
    }
}

extension API {
    /// Watchlist data.
    public struct Watchlist: Decodable {
        /// Watchlist identifier.
        public let identifier: String
        /// Watchlist given name.
        public let name: String
        /// Indicates whether the watchlist can be altered by the user.
        public let isEditable: Bool
        /// Indicates whether the watchlist can be deleted by the user.
        public let isDeleteable: Bool
        /// Indicates whether the watchlist belong to the user or is one predefined by the system.
        public let isPredefined: Bool

        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }

        private enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case name
            case isEditable = "editable"
            case isDeleteable = "deleteable"
            case isPredefined = "defaultSystemWatchlist"
        }
    }
}
