import ReactiveSwift
import Foundation

extension API {
    /// Returns all watchlists belonging to the active account.
    public func watchlists() -> SignalProducer<[API.Response.Watchlist],API.Error> {
        return self.makeRequest(.get, "watchlists", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.WatchlistListWrapper) in w.watchlists }
    }
    
    /// Creates a watchlist.
    /// - parameter name: Watchlist given name.
    /// - parameter epics: List of market epics to be associated to this new watchlist.
    /// - returns: SignalProducer with the watchlist identifier as its value.
    public func createWatchlist(name: String, epics: [String]) -> SignalProducer<(identifier: String, areAllInstrumentAdded: Bool),API.Error> {
        return self.makeRequest(.post, "watchlists", version: 1, credentials: true, body: {
                let body = try API.Request.Watchlist.Creation(name: name, epics: epics)
                return (.json, try API.Codecs.jsonEncoder().encode(body))
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.WatchlistCreationWrapper) in (w.identifier, w.areAllInstrumentAdded) }
    }
    
    /// Returns the targeted watchlist.
    /// - parameter id: The identifier for the watchlist being targeted.
    public func watchlist(id: String) -> SignalProducer<[API.Response.Watchlist.Market],API.Error> {
        return self.makeRequest(.get, "watchlists/\(id)", version: 1, credentials: true, queries: {
                guard !id.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist retrieval failed! The watchlist identifier cannot be empty.") }
                return []
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.WatchlistRetrievalWrapper) in w.markets }
    }
    
    /// Adds a market to a watchlist.
    /// - parameter id: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be added to the watchlist.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func updateWatchlist(id: String, addingEpic epic: String) -> SignalProducer<Void,API.Error> {
        return self.makeRequest(.put, "watchlists/\(id)", version: 1, credentials: true, queries: {
                guard !id.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist update failed! The watchlist identifier cannot be empty.") }
                guard !epic.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist update failed! The epic to be added cannot be empty.") }
                return []
          }, body: {
                let body = ["epic": epic]
                return (.json, try API.Codecs.jsonEncoder().encode(body))
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.WatchlistUpdateWrapper) in return }
    }
    
    /// Removes a market from a watchlist.
    /// - parameter id: The identifier for the watchlist being targeted.
    /// - parameter epic: The market epic to be removed from the watchlist.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func updateWatchlist(id: String, removingEpic epic: String) -> SignalProducer<Void,API.Error> {
        return self.makeRequest(.delete, "watchlists/\(id)/\(epic)", version: 1, credentials: true, queries: {
                guard !id.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist update failed! The watchlist identifier cannot be empty.") }
                guard !epic.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist update failed! The epic to be added cannot be empty.") }
                return []
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.WatchlistUpdateWrapper) in return }
    }
    
    /// Deletes the targeted watchlist.
    /// - parameter id: The identifier for the watchlist being targeted.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func deleteWatchlist(id: String) -> SignalProducer<Void,API.Error> {
        return self.makeRequest(.delete, "watchlists/\(id)", version: 1, credentials: true, queries: {
                guard !id.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist deletion failed! The watchlist identifier cannot be empty.") }
                return []
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (w: API.Response.WatchlistDeletionWrapper) in return }
    }
}

// MARK: -

extension API.Request {
    /// List of watchlist related requests.
    fileprivate enum Watchlist {
        /// A watchlist creation request payload.
        fileprivate struct Creation: Encodable {
            let name: String
            let epics: [String]
            
            init(name: String, epics: [String]) throws {
                guard !name.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Watchlist creation failed! The watchlist name cannot be empty.")
                }
                self.name = name
                self.epics = epics.filter { !$0.isEmpty }
            }
            
            private enum CodingKeys: String, CodingKey {
                case name
                case epics
            }
        }
    }
}

// MARK: -

extension API.Response {
    /// Wrapper around a list of watchlists.
    fileprivate struct WatchlistListWrapper: Decodable {
        let watchlists: [Watchlist]
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
    
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
    
    /// Wrapper for the successful creation of a watchlist.
    fileprivate struct WatchlistCreationWrapper: Decodable {
        /// The watchlist identifier.
        let identifier: String
        /// Indicates wehther all the requested instrument couldn't be added to the list.
        let areAllInstrumentAdded: Bool
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.identifier = try container.decode(String.self, forKey: .identifier)
            let status = try container.decode(Status.self, forKey: .status)
            self.areAllInstrumentAdded = (status == .success)
        }
        
        private enum Status: String, Decodable {
            case success = "SUCCESS"
            case notAllInstrumentAdded = "SUCCESS_NOT_ALL_INSTRUMENTS_ADDED"
        }
        
        private enum CodingKeys: String, CodingKey {
            case identifier = "watchlistId"
            case status = "status"
        }
    }
    
    /// Wrapper for the retrieval of a single watchlist.
    fileprivate struct WatchlistRetrievalWrapper: Decodable {
        /// All markets contained in the targeted watchlist.
        let markets: [Watchlist.Market]
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
    
    /// Wrapper for the update operation targeting a single watchlist.
    fileprivate typealias WatchlistUpdateWrapper = WatchlistDeletionWrapper
    
    /// Wrapper for the watchlist deletion response.
    fileprivate struct WatchlistDeletionWrapper: Decodable {
        /// The operation status.
        let status: Status
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        enum Status: String, Decodable {
            case success = "SUCCESS"
        }
    }
}

extension API.Response.Watchlist {
    /// Market data.
    public struct Market: Decodable {
        /// Instrument details.
        public let instrument: Instrument
        /// Market snapshot data.
        public let snapshot: Snapshot
        
        public init(from decoder: Decoder) throws {
            self.instrument = try Instrument(from: decoder)
            self.snapshot = try Snapshot(from: decoder)
        }
        
        /// Instrument details.
        public struct Instrument: Decodable {
            /// Instrument epic identifier.
            public let epic: String
            /// Instrument name.
            public let name: String
            /// Instrument type.
            public let type: API.Instrument.Kind
            /// Instrument expiration period.
            public let expiry: API.Expiry
            /// Lot size.
            public let lotSize: Double
            /// Boolean indicating whether prices are available through streaming communications.
            public let isAvailableByStreaming: Bool
            /// Exchange identifier for this instrument.
            public let exchangeId: String?
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.epic = try container.decode(String.self, forKey: .epic)
                self.expiry = try container.decodeIfPresent(API.Expiry.self, forKey: .expiry) ?? .none
                self.name = try container.decode(String.self, forKey: .name)
                self.type = try container.decode(API.Instrument.Kind.self, forKey: .type)
                self.lotSize = try container.decode(Double.self, forKey: .lotSize)
                self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isAvailableByStreaming)
                self.exchangeId = try container.decodeIfPresent(String.self, forKey: .exchangeId)
            }
            
            private enum CodingKeys: String, CodingKey {
                case epic
                case expiry
                case name = "instrumentName"
                case type = "instrumentType"
                case lotSize
                case isAvailableByStreaming = "streamingPricesAvailable"
                case exchangeId
            }
        }
        
        /// Market snapshot data.
        public struct Snapshot: Decodable {
            /// Describes the current status of a given market.
            public let status: API.Market.Status
            /// Multiplying factor to determine actual pip value for the levels used by the instrument.
            public let scalingFactor: Double
            /// Time of the last price update.
            public let lastUpdate: Date
            /// Offer (buy) and bid (sell) price.
            public let price: (offer: Double, bid: Double, delay: Double)
            /// Highest and lowest price of the day.
            public let range: (low: Double, high: Double)
            /// Price change net and percentage change on that day.
            public let change: (net: Double, percentage: Double)
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.status = try container.decode(API.Market.Status.self, forKey: .status)
                self.scalingFactor = try container.decode(Double.self, forKey: .scalingFactor)
                self.lastUpdate = try container.decode(Date.self, forKey: .lastUpdate, with: API.DateFormatter.time)
                let offer = try container.decode(Double.self, forKey: .offer)
                let bid = try container.decode(Double.self, forKey: .bid)
                let delay = try container.decode(Double.self, forKey: .delay)
                self.price = (offer, bid, delay)
                let low = try container.decode(Double.self, forKey: .low)
                let high = try container.decode(Double.self, forKey: .high)
                self.range = (low, high)
                let netChange = try container.decode(Double.self, forKey: .netChange)
                let percentageChange = try container.decode(Double.self, forKey: .percentageChange)
                self.change = (netChange, percentageChange)
            }
            
            private enum CodingKeys: String, CodingKey {
                case status = "marketStatus"
                case scalingFactor
                case lastUpdate = "updateTimeUTC"
                case offer, bid, delay = "delayTime"
                case low, high
                case netChange, percentageChange
            }
        }
    }
}
