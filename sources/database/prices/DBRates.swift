import Combine
import Foundation
import Decimals
import SQLite3

extension Database.Request {
    /// Contains all functionality related to interest rates, inflation, etc.
    @frozen public struct Rates {
        /// Pointer to the actual database instance in charge of the low-level objects.
        private let _database: Database
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        @usableFromInline internal init(database: Database) { self._database = database }
    }
}

extension Database.Request.Rates {
    /// Returns the interest rates set by the currencies' central banks during the given time frame.
    /// - parameter currencies: The currencies identifying the targeted central bank interests.
    /// - parameter from: The date from which to start the query (inclusive). If `nil`, the retrieved data starts with the first ever recorded interest rate.
    /// - parameter to: The date from which to end the query (inclusive). If `nil`, the retrieved data ends with the last recorded interest rate.
    /// - returns: The requested central bank interest rates or an empty array if no data has been previously stored for that timeframe.
    public func getInterests(currencies: Set<Currency.Code>, from: Date? = nil, to: Date? = nil) -> AnyPublisher<[Database.InterestRate],IG.Error> {
        guard !currencies.isEmpty else { return Empty().eraseToAnyPublisher() }
        
        return self._database.publisher { _ -> String in
                var query = "SELECT * FROM '\(Database.InterestRate.tableName)'"
                switch (from, to) {
                case (let from?, let to?):
                    guard from <= to else { throw IG.Error._invalidDates() }
                    query.append(" WHERE (date BETWEEN ?1 AND ?2) AND (")
                case (.some, .none): query.append(" WHERE (date >= ?1) AND (")
                case (.none, .some): query.append(" WHERE (date <= ?1) AND (")
                case (.none, .none): query.append(" WHERE (")
                }
            
                query.append(currencies.map { "(currency == '\($0.description)')" }.joined(separator: " OR "))
                query.append(") ORDER BY date ASC")
                return query
            }.read { (sqlite, statement, query) -> [Database.InterestRate] in
                var result: [Database.InterestRate] = []
                // 1. Compile the SQL statement
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                // 2. Add the variables to the statement
                switch (from, to) {
                case (let from?, let to?): sqlite3_bind_text(statement, 1, UTC.Day.string(from: from), -1, SQLite.Destructor.transient)
                                           sqlite3_bind_text(statement, 2, UTC.Day.string(from: to),   -1, SQLite.Destructor.transient)
                case (let from?, .none):   sqlite3_bind_text(statement, 1, UTC.Day.string(from: from), -1, SQLite.Destructor.transient)
                case (.none, let to?):     sqlite3_bind_text(statement, 1, UTC.Day.string(from: to),   -1, SQLite.Destructor.transient)
                case (.none, .none): break
                }
                
                let formatter = UTC.Day()
                while true {
                    switch sqlite3_step(statement).result {
                    case .row: result.append(Database.InterestRate(statement: statement!, formatter: formatter))
                    case .done: return result
                    case let c: throw IG.Error._queryFailed(code: c)
                    }
                }
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Updates the database with the information given as the argument.
    /// - parameter interests: The new data to be included in the database.
    /// - returns: A publisher that completes successfully (without sending any value) if the operation has been successful.
    internal func update(interests: [Database.InterestRate]) -> AnyPublisher<Never,IG.Error> {
        guard !interests.isEmpty else { return Empty().eraseToAnyPublisher() }
        return self._database.publisher { _ -> String in
                "INSERT INTO '\(Database.InterestRate.tableName)' VALUES(?1, ?2, ?3) ON CONFLICT(date,currency) DO UPDATE SET rate=excluded.rate"
            }.write { (sqlite, statement, query) -> Void in
                // 1. Compile the SQL statement.
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                // 2. Write the elements iteratively.
                for rate in interests {
                    rate._bind(to: statement!)
                    try sqlite3_step(statement).expects(.done) { IG.Error._storingFailed(code: $0) }
                    sqlite3_clear_bindings(statement)
                    sqlite3_reset(statement)
                }
            }.ignoreOutput()
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

private extension IG.Error {
    /// Error raised when the _from_ and _to_ date interval are invalid.
    static func _invalidDates() -> Self {
        Self(.database(.invalidRequest), "The 'from' date must indicate a date before the 'to' date", help: "Read the request documentation and be sure to follow all requirements.")
    }
    /// Error raised when a SQLite command couldn't be compiled.
    static func _compilationFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred trying to compile a SQL statement.", info: ["Error code": code])
    }
    /// Error raised when a SQLite table fails.
    static func _queryFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred querying the SQLite table.", info: ["Table": Database.InterestRate.self, "Error code": code])
    }
    /// Error raised when storing fails.
    static func _storingFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred storing values on '\(Database.InterestRate.self)'.", info: ["Error code": code])
    }
}
