import Combine
import Foundation
import SQLite3

extension Database.Request {
    /// Contains all functionality related to Database applications.
    @frozen public struct Accounts {
        /// Pointer to the actual database instance in charge of the low-level objects..
        private unowned let _database: Database
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        @usableFromInline internal init(database: Database) { self._database = database }
    }
}

extension Database.Request.Accounts {
    /// Returns all applications stored in the database.
    /// - returns: Discrete publisher producing a single value containing an array of all stored applications and then successfully completes.
    public func getApplications() -> AnyPublisher<[Database.Application],IG.Error> {
        self._database.publisher { _ in "SELECT * FROM \(Database.Application.tableName)" }
            .read { (sqlite, statement, query) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                
                var result: [Database.Application] = []
                while true {
                    switch sqlite3_step(statement).result {
                    case .row:  result.append(.init(statement: statement!))
                    case .done: return result
                    case let e: throw IG.Error._queryFailed(code: e)
                    }
                }
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }

    /// Returns the application specified by its API key.
    ///
    /// If the application is not found, an `.invalidResponse` is returned.
    /// - parameter key: The API key identifying the application.
    public func getApplication(key: API.Key) -> AnyPublisher<Database.Application,IG.Error> {
        self._database.publisher { _ in "SELECT * FROM Apps where key = ?1" }
            .read { (sqlite, statement, query) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                try sqlite3_bind_text(statement, 1, key.description, -1, SQLite.Destructor.transient).expects(.ok) { IG.Error._bindingFailed(code: $0) }
                
                switch sqlite3_step(statement).result {
                case .row:  return Database.Application(statement: statement!)
                case .done: throw IG.Error._unfoundRequestValue()
                case let e: throw IG.Error._queryFailed(code: e)
                }
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }

    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter applications: Information returned from the server.
    public func update(applications: [API.Application]) -> AnyPublisher<Never,IG.Error> {
        self._database.publisher { _ in
            """
            INSERT INTO \(Database.Application.tableName) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, CURRENT_TIMESTAMP)
                ON CONFLICT(key) DO UPDATE SET
                    name = excluded.name, status = excluded.status,
                    equity = excluded.equity, quote = excluded.quote,
                    liApp = excluded.liApp, liAcco = excluded.liAcco, liTrade = excluded.liTrade, liHisto = excluded.liHisto, subs = excluded.subs,
                    created = excluded.created, updated = excluded.updated
            """
        }.write { (sqlite, statement, query) in
            try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
            
            for app in applications {
                let status = Database.Application.Status(app.status)
                let permission = Database.Application.Permission(accessToEquityPrices: app.permission.accessToEquityPrices, areQuoteOrdersAllowed: app.permission.areQuoteOrdersAllowed)
                let account = Database.Application.Allowance.Account(overallRequests: app.allowance.account.overallRequests, tradingRequests: app.allowance.account.tradingRequests, historicalDataRequests: app.allowance.account.historicalDataRequests)
                let allowance = Database.Application.Allowance(overallRequests: app.allowance.overallRequests, account: account, concurrentSubscriptions: app.allowance.subscriptionsLimit)
                
                Database.Application(key: app.key, name: app.name, status: status, permission: permission, allowance: allowance, created: app.date, updated: Date())
                    ._bind(to: statement!)

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
        Self(.database(.callFailed), "An error occurred querying the SQLite table.", info: ["Table": Database.Application.self, "Error code": code])
    }
    /// Error raised when a request value isn't found.
    static func _unfoundRequestValue() -> Self {
        Self(.database(.invalidResponse), "The requested value couldn't be found.", help: "The value is not in the database. Please introduce it, before trying to query it.")
    }
    /// Error raised when a SQLite command fails.
    static func _storingFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred storing values.", info: ["Table": Database.Application.self, "Error code": code])
    }
}
