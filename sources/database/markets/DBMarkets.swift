import Combine
import Foundation
import SQLite3

extension Database.Request {
    /// Contains all functionality related to Database markets.
    @frozen public struct Markets {
        /// Pointer to the actual database instance in charge of the low-level objects.
        private let _database: Database
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        @usableFromInline internal init(database: Database) { self._database = database }
        
        /// It holds data and functionality related to the forex markets.
        public var forex: Database.Request.Markets.Forex { .init(database: self._database) }
    }
}

extension Database.Request.Markets {
    /// Returns an array for which each element has the epic and a Boolean indicating whether the market is currently stored on the database or not.
    /// - parameter epics: Array of market identifiers to be checked against the database.
    public func contains(epics: Set<IG.Market.Epic>) -> AnyPublisher<[(epic: IG.Market.Epic, isInDatabase: Bool)],IG.Error> {
        guard !epics.isEmpty else { return Result.Publisher([]).eraseToAnyPublisher() }
        
        return self._database.publisher { _ -> String in
                let clause = epics.enumerated().map { (index, _) in "epic=?\(index+1)" }.joined(separator: " OR ")
                return "SELECT epic FROM \(Database.Market.tableName) WHERE \(clause)"
            }.read { (sqlite, statement, query) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                
                for (index, epic) in epics.enumerated() {
                    try sqlite3_bind_text(statement, .init(index) + 1, epic.description, -1, SQLite.Destructor.transient).expects(.ok) { IG.Error._bindingFailed(code: $0) }
                }
                
                var result: Set<IG.Market.Epic> = .init()
                rowIterator: while true {
                    switch sqlite3_step(statement).result {
                    case .row: result.insert( IG.Market.Epic(String(cString: sqlite3_column_text(statement.unsafelyUnwrapped, 0)))! )
                    case .done: break rowIterator
                    case let e: throw IG.Error._queryFailed(code: e)
                    }
                }
                
                return epics.map { ($0, result.contains($0)) }
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Returns all markets stored in the database.
    ///
    /// Only the epic and the type of markets are returned.
    public func getAll() -> AnyPublisher<[Database.Market],IG.Error> {
        self._database.publisher { _ in "SELECT * FROM \(Database.Market.tableName)" }
            .read { (sqlite, statement, query) -> [Database.Market] in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                
                var result: [Database.Market] = .init()
                while true {
                    switch sqlite3_step(statement).result {
                    case .row:  result.append(.init(statement: statement.unsafelyUnwrapped))
                    case .done: return result
                    case let e: throw IG.Error._queryFailed(code: e)
                    }
                }
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Returns the type of Market identified by the given epic.
    /// - parameter epic: Market instrument identifier.
    /// - returns: `SignalProducer` returning the market type or `nil` if the market has been found in the database. If the epic didn't matched any stored market, the producer generates an error `IG.Error.invalidResponse`.
    public func type(epic: IG.Market.Epic) -> AnyPublisher<Database.Market.Kind?,IG.Error> {
        self._database.publisher { _ in "SELECT type FROM \(Database.Market.tableName) WHERE epic=?1" }
            .read { (sqlite, statement, query) -> Database.Market.Kind? in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                try sqlite3_bind_text(statement, 1, epic.description, -1, SQLite.Destructor.transient).expects(.ok) { IG.Error._bindingFailed(code: $0) }
                
                switch sqlite3_step(statement).result {
                case .row:  return Database.Market.Kind(rawValue: sqlite3_column_int(statement, 0))
                case .done: throw IG.Error._unfoundRequestValue()
                case let e: throw IG.Error._queryFailed(code: e)
                }
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter market: Information returned from the server.
    public func update(_ market: API.Market...) -> AnyPublisher<Never,IG.Error> {
        self.update(market)
    }
    
    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter markets: Information returned from the server.
    public func update(_ markets: [API.Market]) -> AnyPublisher<Never,IG.Error> {
        self._database.publisher { _ in "INSERT INTO \(Database.Market.tableName) VALUES(?1, ?2) ON CONFLICT(epic) DO UPDATE SET type=excluded.type" }
            .write { (sqlite, statement, query) -> Void in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                
                for apiMarket in markets {
                    let dbMarket = Database.Market(epic: apiMarket.instrument.epic, type: Database.Market.Kind(market: apiMarket))
                    dbMarket._bind(to: statement.unsafelyUnwrapped)

                    try sqlite3_step(statement).expects(.done) { IG.Error._storingFailed(code: $0) }
                    sqlite3_clear_bindings(statement)
                    sqlite3_reset(statement)
                }
                
                sqlite3_finalize(statement); statement = nil
                try Self.Forex.update(markets: markets, sqlite: sqlite)
            }.ignoreOutput()
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

private extension IG.Error {
    /// Error raised when a SQLite command couldn't be compiled.
    static func _compilationFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred trying to compile a SQL statement.", info: ["Error code": code])
    }
    /// Error raised when a SQLite binding couldn't take place.
    static func _bindingFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred binding attributes to a SQL statement.", info: ["Error code": code])
    }
    /// Error raised when a SQLite table fails.
    static func _queryFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred querying the SQLite table.", info: ["Table": Database.Market.self, "Error code": code])
    }
    /// Error raised when a request value isn't found.
    static func _unfoundRequestValue() -> Self {
        Self(.database(.invalidResponse), "The requested value couldn't be found.", help: "The value is not in the database. Please introduce it, before trying to query it.")
    }
    /// Error raised when storing fails.
    static func _storingFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred storing values on '\(Database.Market.self)'.", info: ["Error code": code])
    }
}
