import Combine
import Foundation
import SQLite3

extension Database.Request {
    /// Contains all functionality related to Database markets.
    public struct Markets {
        /// Pointer to the actual database instance in charge of the low-level objects.
        fileprivate unowned let _database: Database
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        @usableFromInline internal init(database: Database) { self._database = database }
        
        /// It holds data and functionality related to the forex markets.
        public var forex: Database.Request.Markets.Forex { .init(database: self._database) }
    }
}

extension Database.Request.Markets {
    /// Returns an array for which each element has the epic and a Boolean indicating whether the market is currently stored on the database or not.
    /// - parameter epics: Array of market identifiers to be checked against the database.
    public func contains(epics: Set<IG.Market.Epic>) -> AnyPublisher<[(epic: IG.Market.Epic, isInDatabase: Bool)],Database.Error> {
        guard !epics.isEmpty else { return Result.Publisher([]).eraseToAnyPublisher() }
        
        return self._database.publisher { _ -> String in
                let clause = epics.enumerated().map { (index, _) in "epic=?\(index+1)" }.joined(separator: " OR ")
                return "SELECT epic FROM \(Database.Market.tableName) WHERE \(clause)"
            }.read { (sqlite, statement, query, _) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                
                for (index, epic) in epics.enumerated() {
                    try sqlite3_bind_text(statement, .init(index) + 1, epic.rawValue, -1, SQLite.Destructor.transient).expects(.ok) { .callFailed(.bindingAttributes, code: $0) }
                }
                
                var result: Set<IG.Market.Epic> = .init()
                rowIterator: while true {
                    switch sqlite3_step(statement).result {
                    case .row: result.insert( IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(statement!, 0)))! )
                    case .done: break rowIterator
                    case let e: throw Database.Error.callFailed(.querying(Database.Market.self), code: e)
                    }
                }
                
                return epics.map { ($0, result.contains($0)) }
            }.mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }
    
    /// Returns all markets stored in the database.
    ///
    /// Only the epic and the type of markets are returned.
    public func getAll() -> AnyPublisher<[Database.Market],Database.Error> {
        self._database.publisher { _ in
                "SELECT * FROM \(Database.Market.tableName)"
            }.read { (sqlite, statement, query, _) -> [Database.Market] in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                
                var result: [Database.Market] = .init()
                while true {
                    switch sqlite3_step(statement).result {
                    case .row:  result.append(.init(statement: statement!))
                    case .done: return result
                    case let e: throw Database.Error.callFailed(.querying(Database.Market.self), code: e)
                    }
                }
            }.mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }
    
    /// Returns the type of Market identified by the given epic.
    /// - parameter epic: Market instrument identifier.
    /// - returns: `SignalProducer` returning the market type or `nil` if the market has been found in the database. If the epic didn't matched any stored market, the producer generates an error `Database.Error.invalidResponse`.
    public func type(epic: IG.Market.Epic) -> AnyPublisher<Database.Market.Kind?,Database.Error> {
        self._database.publisher { _ in
                "SELECT type FROM \(Database.Market.tableName) WHERE epic=?1"
            }.read { (sqlite, statement, query, _) -> Database.Market.Kind? in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                try sqlite3_bind_text(statement, 1, epic.rawValue, -1, SQLite.Destructor.transient).expects(.ok) { .callFailed(.bindingAttributes, code: $0) }
                
                switch sqlite3_step(statement).result {
                case .row:  return Database.Market.Kind(rawValue: sqlite3_column_int(statement, 0))
                case .done: throw Database.Error.invalidResponse(.valueNotFound, suggestion: .valueNotFound)
                case let e: throw Database.Error.callFailed(.querying(Database.Market.self), code: e)
                }
            }.mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }
    
    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter market: Information returned from the server.
    public func update(_ market: API.Market...) -> AnyPublisher<Never,Database.Error> {
        self.update(market)
    }
    
    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter markets: Information returned from the server.
    public func update(_ markets: [API.Market]) -> AnyPublisher<Never,Database.Error> {
        self._database.publisher { _ in
                """
                INSERT INTO \(Database.Market.tableName) VALUES(?1, ?2)
                    ON CONFLICT(epic) DO UPDATE SET type=excluded.type
                """
            }.write { (sqlite, statement, query, _) -> Void in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                
                for apiMarket in markets {
                    let dbMarket = Database.Market(epic: apiMarket.instrument.epic, type: Database.Market.Kind(market: apiMarket))
                    dbMarket._bind(to: statement!)

                    try sqlite3_step(statement).expects(.done) { .callFailed(.storing(Database.Market.self), code: $0) }
                    sqlite3_clear_bindings(statement)
                    sqlite3_reset(statement)
                }
                
                sqlite3_finalize(statement); statement = nil
                try Self.Forex.update(markets: markets, sqlite: sqlite)
            }.ignoreOutput()
            .mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension Database {
    /// List of all markets within the IG platform.
    public struct Market {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// The type of market (i.e. instrument type).
        public let type: Self.Kind?
    }
}

extension Database.Market {
    /// The type of market (i.e. instrument type).
    /// - todo: More will be added conforming support is rolled out.
    public enum Kind: RawRepresentable {
        /// Currencies are medium of exchange.
        case currencies(Self.Currency)
        /// An index is an statistical measure of change in a securities market.
        case indices

        public enum Currency {
            case forex
        }
    }
}

// MARK: - Functionality

// MARK: SQLite

extension Database.Market: DBTable {
    internal static let tableName: String = "Markets"
    internal static var tableDefinition: String { """
        CREATE TABLE \(Self.tableName) (
            epic  TEXT    NOT NULL CHECK( LENGTH(epic) BETWEEN 6 AND 30 ),
            type  INTEGER,
            
            PRIMARY KEY(epic)
        ) WITHOUT ROWID;
        """
    }
}

fileprivate extension Database.Market {
    typealias _Indices = (epic: Int32, type: Int32)
    
    init(statement s: SQLite.Statement, indices: _Indices = (0, 1)) {
        self.epic = IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(s, indices.epic)))!
        self.type = Self.Kind(rawValue: sqlite3_column_int(s, indices.type))    // Implicit SQLite conversion from `NULL` to `0`
    }
    
    func _bind(to statement: SQLite.Statement, indices: _Indices = (1, 2)) {
        sqlite3_bind_text(statement, indices.epic, self.epic.rawValue, -1, SQLite.Destructor.transient)
        self.type.unwrap( none: { sqlite3_bind_null(statement, indices.type) },
                          some: { sqlite3_bind_int (statement, indices.type, $0.rawValue) })
    }
}

// MARK: API

extension Database.Market.Kind: Equatable {
    public init?(rawValue: Int32) {
        typealias V = _Value
        switch rawValue {
        case 0: return nil
        case V.currenciesForex:  self = .currencies(.forex)
        case V.indices:          self = .indices
        default: return nil
        }
    }
    
    fileprivate init?(market: API.Market) {
        switch market.instrument.type {
        case .currencies where Database.Market.Forex.isCompatible(market: market): self = .currencies(.forex)
//        case .indices:     self = .indices
//        case .rates:       self = .rates
//        case .options:     self = .options
//        case .shares:      self = .shares
//        case .commodities: self = .commodities
        default: return nil
        }
    }
    
    public var rawValue: Int32 {
        typealias V = _Value
        switch self {
        case .currencies(.forex):  return V.currenciesForex
        case .indices:             return V.indices
        }
    }
    
    private enum _Value {
        static let currencies:       Int32 = 1
        static let currenciesForex:  Int32 = Self.currencies | (1 << 16)
        static let indices:          Int32 = 2
    }
}

// MARK: Debugging

extension Database.Market: IG.DebugDescriptable {
    internal static var printableDomain: String { Database.printableDomain.appending(".\(Self.self)") }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("epic", self.epic.rawValue)
        result.append("type", self.type.debugDescription)
        return result.generate()
    }
}

extension Database.Market.Kind {
    public var debugDescription: String {
        switch self {
        case .currencies: return "currencies"
        case .indices: return "indices"
        }
    }
}
