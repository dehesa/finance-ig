import Combine
import Foundation
import SQLite3

extension Database.Request {
    /// Contains all functionality related to Database applications.
    public struct Accounts {
        /// Pointer to the actual database instance in charge of the low-level objects..
        fileprivate unowned let _database: Database
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        @usableFromInline internal init(database: Database) { self._database = database }
    }
}

extension Database.Request.Accounts {
    /// Returns all applications stored in the database.
    /// - returns: Discrete publisher producing a single value containing an array of all stored applications and then successfully completes.
    public func getApplications() -> AnyPublisher<[Database.Application],Database.Error> {
        self._database.publisher { _ in
                "SELECT * FROM \(Database.Application.tableName)"
            }.read { (sqlite, statement, query, _) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                
                var result: [Database.Application] = .init()
                while true {
                    switch sqlite3_step(statement).result {
                    case .row:  result.append(.init(statement: statement!))
                    case .done: return result
                    case let e: throw Database.Error.callFailed(.querying(Database.Application.self), code: e)
                    }
                }
            }.mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }

    /// Returns the application specified by its API key.
    ///
    /// If the application is not found, an `.invalidResponse` is returned.
    /// - parameter key: The API key identifying the application.
    public func getApplication(key: API.Key) -> AnyPublisher<Database.Application,Database.Error> {
        self._database.publisher { _ in
                "SELECT * FROM Apps where key = ?1"
            }.read { (sqlite, statement, query, _) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                try sqlite3_bind_text(statement, 1, key.rawValue, -1, SQLite.Destructor.transient).expects(.ok) { .callFailed(.bindingAttributes, code: $0) }
                
                switch sqlite3_step(statement).result {
                case .row:  return .init(statement: statement!)
                case .done: throw Database.Error.invalidResponse(.valueNotFound, suggestion: .valueNotFound)
                case let e: throw Database.Error.callFailed(.querying(Database.Application.self), code: e)
                }
            }.mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }

    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter applications: Information returned from the server.
    public func update(applications: [API.Application]) -> AnyPublisher<Never,Database.Error> {
        self._database.publisher { _ in
            """
            INSERT INTO \(Database.Application.tableName) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, CURRENT_TIMESTAMP)
                ON CONFLICT(key) DO UPDATE SET
                    name = excluded.name, status = excluded.status,
                    equity = excluded.equity, quote = excluded.quote,
                    liApp = excluded.liApp, liAcco = excluded.liAcco, liTrade = excluded.liTrade, liHisto = excluded.liHisto, subs = excluded.subs,
                    created = excluded.created, updated = excluded.updated
            """
        }.write { (sqlite, statement, query, _) in
            try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
            
            for app in applications {
                Database.Application(key: app.key, name: app.name, status: .init(app.status),
                                  permission: .init(accessToEquityPrices: app.permission.accessToEquityPrices,
                                                    areQuoteOrdersAllowed: app.permission.areQuoteOrdersAllowed),
                                  allowance: .init(overallRequests: app.allowance.overallRequests,
                                                   account: .init(overallRequests: app.allowance.account.overallRequests,
                                                                  tradingRequests: app.allowance.account.tradingRequests,
                                                                  historicalDataRequests: app.allowance.account.historicalDataRequests),
                                                   concurrentSubscriptions: app.allowance.subscriptionsLimit),
                                  created: app.creationDate,
                                  updated: Date())
                    ._bind(to: statement!)

                try sqlite3_step(statement).expects(.done) { .callFailed(.storing(Database.Application.self), code: $0) }
                sqlite3_clear_bindings(statement)
                sqlite3_reset(statement)
            }
        }.ignoreOutput()
        .mapError(Database.Error.transform)
        .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension Database {
    /// Client application
    public struct Application {
        /// Application API key identifying the application and the developer.
        public let key: API.Key
        /// Application name given by the developer.
        public let name: String
        ///  Application status.
        public let status: Self.Status
        /// What the platform allows the application or account to do (e.g. requests per minute).
        public let permission: Self.Permission
        /// The limits at which the receiving application is constrained to.
        public let allowance: Self.Allowance
        /// Application creation date (referencing UTC dates, although no time data is stored).
        public let created: Date
        /// The date at which this entity was inserted in the database with factual information.
        public let updated: Date
    }
}

extension Database.Application {
    /// Application status in the platform.
    public enum Status: Int32 {
        /// The application is enabled and thus ready to receive/send data.
        case enabled = 1
        /// The application has been disabled by the developer.
        case disabled = 0
        /// The application has been revoked by the admins.
        case revoked = -1
    }
    
    /// The platform allowance to the application's and account's allowances (e.g. requests per minute).
    public struct Permission {
        /// Boolean indicating if access to equity prices is permitted.
        public let accessToEquityPrices: Bool
        /// Boolean indicating if quote orders are permitted.
        public let areQuoteOrdersAllowed: Bool
    }
    
    /// The restrictions constraining an API application.
    public struct Allowance {
        /// Overal application request per minute allowance.
        public let overallRequests: Int
        /// Account related requests per minute allowance.
        public let account: Self.Account
        /// Concurrent subscriptioon limit per lightstreamer connection.
        public let concurrentSubscriptions: Int
        
        /// Limit and allowances for the targeted account.
        public struct Account {
            /// Per account request per minute allowance.
            public let overallRequests: Int
            /// Per account trading request per minute allowance.
            public let tradingRequests: Int
            /// Historical price data data points per minute allowance.
            public let historicalDataRequests: Int
        }
    }
}

// MARK: - Functionality

// MARK: SQLite

extension Database.Application: DBTable {
    internal static let tableName: String = "Apps"
    internal static var tableDefinition: String { """
        CREATE TABLE \(Self.tableName) (
            key     TEXT    NOT NULL CHECK( LENGTH(key) == 40 ),
            name    TEXT    NOT NULL CHECK( LENGTH(name) > 0 ),
            status  INTEGER NOT NULL CHECK( status BETWEEN -1 AND 1 ),
            equity  INTEGER NOT NULL CHECK( equity BETWEEN 0 AND 1 ),
            quote   INTEGER NOT NULL CHECK( quote BETWEEN 0 AND 1 ),
            liApp   INTEGER NOT NULL CHECK( liApp >= 0 ),
            liAcco  INTEGER NOT NULL CHECK( liAcco >= 0 ),
            liTrade INTEGER NOT NULL CHECK( liTrade >= 0 ),
            liHisto INTEGER NOT NULL CHECK( liHisto >= 0 ),
            subs    INTEGER NOT NULL CHECK( subs >= 0 ),
            created TEXT    NOT NULL CHECK( (created IS DATE(created)) AND (created <= CURRENT_DATE) ),
            updated TEXT    NOT NULL CHECK( (updated IS DATETIME(updated)) AND (updated <= CURRENT_TIMESTAMP) ),
        
            PRIMARY KEY(key)
        ) WITHOUT ROWID;
        """
    }
}

fileprivate extension Database.Application {
    typealias _Indices = (key: Int32, name: Int32, status: Int32, permission: Self.Permission._Indices, allowance: Self.Allowance._Indices, created: Int32, updated: Int32)
    
    init(statement s: SQLite.Statement, indices: _Indices = (0, 1, 2, (3, 4), (5, (6, 7, 8), 9), 10, 11)) {
        self.key = API.Key(rawValue: String(cString: sqlite3_column_text(s, indices.key)))!
        self.name = String(cString: sqlite3_column_text(s, indices.name))
        self.status = Self.Status(rawValue: sqlite3_column_int(s, indices.status))!
        self.permission = .init(statement: s, indices: indices.permission)
        self.allowance = .init(statement: s, indices: indices.allowance)
        self.created = DateFormatter.date.date(from: String(cString: sqlite3_column_text(s, indices.created)))!
        self.updated = DateFormatter.timestamp.date(from: String(cString: sqlite3_column_text(s, indices.updated)))!
    }
    
    func _bind(to statement: SQLite.Statement, indices: _Indices = (1, 2, 3, (4, 5), (6, (7, 8, 9), 10), 11, 12)) {
        sqlite3_bind_text(statement, indices.key,    self.key.rawValue, -1, SQLite.Destructor.transient)
        sqlite3_bind_text(statement, indices.name,   self.name, -1, SQLite.Destructor.transient)
        sqlite3_bind_int (statement, indices.status, status.rawValue)
        self.permission._bind(to: statement, indices: indices.permission)
        self.allowance._bind(to: statement, indices: indices.allowance)
        sqlite3_bind_text(statement, indices.created, DateFormatter.date.string(from: self.created), -1, SQLite.Destructor.transient)
    }   // Updated is not written for now.
}

fileprivate extension Database.Application.Permission {
    typealias _Indices = (equity: Int32, quotes: Int32)
    
    init(statement s: SQLite.Statement, indices: _Indices) {
        self.accessToEquityPrices = Bool(sqlite3_column_int(s, indices.equity))
        self.areQuoteOrdersAllowed = Bool(sqlite3_column_int(s, indices.quotes))
    }
    
    func _bind(to statement: SQLite.Statement, indices: _Indices) {
        sqlite3_bind_int(statement, indices.equity, Int32(self.accessToEquityPrices))
        sqlite3_bind_int(statement, indices.quotes, Int32(self.areQuoteOrdersAllowed))
    }
}

fileprivate extension Database.Application.Allowance {
    typealias _Indices = (overall: Int32, account: Self.Account._Indices, subs: Int32)
    
    init(statement s: SQLite.Statement, indices: _Indices) {
        self.overallRequests = Int(sqlite3_column_int(s, indices.overall))
        self.account = .init(statement: s, indices: indices.account)
        self.concurrentSubscriptions = Int(sqlite3_column_int(s, indices.subs))
    }
    
    func _bind(to statement: SQLite.Statement, indices: _Indices) {
        sqlite3_bind_int(statement, indices.overall, Int32(self.overallRequests))
        self.account._bind(to: statement, indices: indices.account)
        sqlite3_bind_int(statement, indices.subs, Int32(self.concurrentSubscriptions))
    }
}

fileprivate extension Database.Application.Allowance.Account {
    typealias _Indices = (overall: Int32, trading: Int32, historical: Int32)
    
    init(statement s: SQLite.Statement, indices: _Indices) {
        self.overallRequests = Int(sqlite3_column_int(s, indices.overall))
        self.tradingRequests = Int(sqlite3_column_int(s, indices.trading))
        self.historicalDataRequests = Int(sqlite3_column_int(s, indices.historical))
    }
    
    func _bind(to statement: SQLite.Statement, indices: _Indices) {
        sqlite3_bind_int(statement, indices.overall,    Int32(self.overallRequests))
        sqlite3_bind_int(statement, indices.trading,    Int32(self.tradingRequests))
        sqlite3_bind_int(statement, indices.historical, Int32(self.historicalDataRequests))
    }
}

// MARK: API

fileprivate extension Database.Application.Status {
    init(_ status: API.Application.Status) {
        switch status {
        case .enabled:  self = .enabled
        case .disabled: self = .disabled
        case .revoked:  self = .revoked
        }
    }
}
