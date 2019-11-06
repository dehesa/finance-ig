import Combine
import Foundation
import SQLite3

extension IG.DB.Request {
    /// Contains all functionality related to DB markets.
    public struct Markets {
        /// Pointer to the actual database instance in charge of the low-level objects.
        fileprivate unowned let database: IG.DB
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        internal init(database: IG.DB) { self.database = database }
        
        /// It holds data and functionality related to the forex markets.
        public var forex: IG.DB.Request.Markets.Forex { return .init(database: self.database) }
    }
}

extension IG.DB.Request.Markets {
    /// Returns an array for which each element has the epic and a Boolean indicating whether the market is currently stored on the database or not.
    /// - parameter epics: Array of market identifiers to be checked against the database.
    public func contains(epics: Set<IG.Market.Epic>) -> IG.DB.Publishers.Discrete<[(epic: IG.Market.Epic, isInDatabase: Bool)]> {
        guard !epics.isEmpty else {
            return Just([]).setFailureType(to: IG.DB.Error.self).eraseToAnyPublisher()
        }
        
        return self.database.publisher { _ -> String in
                let clause = epics.enumerated().map { (index, _) in "epic=?\(index+1)" }.joined(separator: " OR ")
                return "SELECT epic FROM \(IG.DB.Market.tableName) WHERE \(clause)"
            }.read { (sqlite, statement, query) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                
                for (index, epic) in epics.enumerated() {
                    try sqlite3_bind_text(statement, .init(index) + 1, epic.rawValue, -1, SQLite.Destructor.transient).expects(.ok) { .callFailed(.bindingAttributes, code: $0) }
                }
                
                var result: Set<IG.Market.Epic> = .init()
                rowIterator: while true {
                    switch sqlite3_step(statement).result {
                    case .row: result.insert( IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(statement!, 0)))! )
                    case .done: break rowIterator
                    case let e: throw IG.DB.Error.callFailed(.querying(IG.DB.Market.self), code: e)
                    }
                }
                
                return epics.map { ($0, result.contains($0)) }
            }.mapError(IG.DB.Error.transform)
            .eraseToAnyPublisher()
    }
    
    /// Returns all markets stored in the database.
    ///
    /// Only the epic and the type of markets are returned.
    public func getAll() -> IG.DB.Publishers.Discrete<[IG.DB.Market]> {
        self.database.publisher { _ in
                "SELECT * FROM \(IG.DB.Market.tableName)"
            }.read { (sqlite, statement, query) -> [IG.DB.Market] in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                
                var result: [IG.DB.Market] = .init()
                while true {
                    switch sqlite3_step(statement).result {
                    case .row:  result.append(.init(statement: statement!))
                    case .done: return result
                    case let e: throw IG.DB.Error.callFailed(.querying(IG.DB.Market.self), code: e)
                    }
                }
            }.mapError(IG.DB.Error.transform)
            .eraseToAnyPublisher()
    }
    
    /// Returns the type of Market identified by the given epic.
    /// - parameter epic: Market instrument identifier.
    /// - returns: `SignalProducer` returning the market type or `nil` if the market has been found in the database. If the epic didn't matched any stored market, the producer generates an error `IG.DB.Error.invalidResponse`.
    public func type(epic: IG.Market.Epic) -> IG.DB.Publishers.Discrete<IG.DB.Market.Kind?> {
        self.database.publisher { _ in
                "SELECT type FROM \(IG.DB.Market.tableName) WHERE epic=?1"
            }.read { (sqlite, statement, query) -> IG.DB.Market.Kind? in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                try sqlite3_bind_text(statement, 1, epic.rawValue, -1, SQLite.Destructor.transient).expects(.ok) { .callFailed(.bindingAttributes, code: $0) }
                
                switch sqlite3_step(statement).result {
                case .row:  return IG.DB.Market.Kind(rawValue: sqlite3_column_int(statement, 0))
                case .done: throw IG.DB.Error.invalidResponse(.valueNotFound, suggestion: .valueNotFound)
                case let e: throw IG.DB.Error.callFailed(.querying(IG.DB.Market.self), code: e)
                }
            }.mapError(IG.DB.Error.transform)
            .eraseToAnyPublisher()
    }
    
    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter market: Information returned from the server.
    public func update(_ market: IG.API.Market...) -> IG.DB.Publishers.Discrete<Never> {
        self.update(market)
    }
    
    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter markets: Information returned from the server.
    public func update(_ markets: [IG.API.Market]) -> IG.DB.Publishers.Discrete<Never> {
        self.database.publisher { _ in
                """
                INSERT INTO \(IG.DB.Market.tableName) VALUES(?1, ?2)
                    ON CONFLICT(epic) DO UPDATE SET type=excluded.type
                """
            }.write { (sqlite, statement, query) -> Void in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                
                for apiMarket in markets {
                    let dbMarket = IG.DB.Market(epic: apiMarket.instrument.epic, type: IG.DB.Market.Kind(market: apiMarket))
                    dbMarket.bind(to: statement!)

                    try sqlite3_step(statement).expects(.done) { .callFailed(.storing(IG.DB.Market.self), code: $0) }
                    sqlite3_clear_bindings(statement)
                    sqlite3_reset(statement)
                }
                
                sqlite3_finalize(statement); statement = nil
                try Self.Forex.update(markets: markets, sqlite: sqlite)
            }.ignoreOutput()
            .mapError(IG.DB.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.DB {
    /// List of all markets within the IG platform.
    public struct Market {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// The type of market (i.e. instrument type).
        public let type: Self.Kind?
    }
}

extension IG.DB.Market {
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

extension IG.DB.Market: DBTable {
    internal static let tableName: String = "Markets"
    internal static var tableDefinition: String { return """
        CREATE TABLE \(Self.tableName) (
            epic  TEXT    NOT NULL CHECK( LENGTH(epic) BETWEEN 6 AND 30 ),
            type  INTEGER,
            
            PRIMARY KEY(epic)
        ) WITHOUT ROWID;
        """
    }
}

fileprivate extension IG.DB.Market {
    typealias Indices = (epic: Int32, type: Int32)
    
    init(statement s: SQLite.Statement, indices: Self.Indices = (0, 1)) {
        self.epic = IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(s, indices.epic)))!
        self.type = Self.Kind(rawValue: sqlite3_column_int(s, indices.type))    // Implicit SQLite conversion from `NULL` to `0`
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices = (1, 2)) {
        sqlite3_bind_text(statement, indices.epic, self.epic.rawValue, -1, SQLite.Destructor.transient)
        self.type.unwrap( none: { sqlite3_bind_null(statement, indices.type) },
                          some: { sqlite3_bind_int (statement, indices.type, $0.rawValue) })
    }
}

// MARK: API

extension IG.DB.Market.Kind: Equatable {
    public init?(rawValue: Int32) {
        typealias V = Self.Value
        switch rawValue {
        case 0: return nil
        case V.currenciesForex:  self = .currencies(.forex)
        case V.indices:          self = .indices
        default: return nil
        }
    }
    
    fileprivate init?(market: IG.API.Market) {
        switch market.instrument.type {
        case .currencies where IG.DB.Market.Forex.isCompatible(market: market): self = .currencies(.forex)
//        case .indices:     self = .indices
//        case .rates:       self = .rates
//        case .options:     self = .options
//        case .shares:      self = .shares
//        case .commodities: self = .commodities
        default: return nil
        }
    }
    
    public var rawValue: Int32 {
        typealias V = Self.Value
        switch self {
        case .currencies(.forex):  return V.currenciesForex
        case .indices:             return V.indices
        }
    }
    
    private enum Value {
        static let currencies:       Int32 = 1
        static let currenciesForex:  Int32 = Self.currencies | (1 << 16)
        static let indices:          Int32 = 2
    }
}

// MARK: Debugging

extension IG.DB.Market: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return IG.DB.printableDomain.appending(".\(Self.self)")
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("epic", self.epic.rawValue)
        result.append("type", self.type.debugDescription)
        return result.generate()
    }
}

extension IG.DB.Market.Kind {
    public var debugDescription: String {
        switch self {
        case .currencies: return "currencies"
        case .indices: return "indices"
        }
    }
}
