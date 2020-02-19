import Combine
import Foundation
import SQLite3

extension IG.Database.Request {
    /// Contains all functionality related to Database applications.
    public struct Accounts {
        /// Pointer to the actual database instance in charge of the low-level objects..
        fileprivate unowned let database: IG.Database
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        internal init(database: IG.Database) { self.database = database }
    }
}

extension IG.Database.Request.Accounts {
    /// Returns all applications stored in the database.
    /// - returns: Discrete publisher producing a single value containing an array of all stored applications and then successfully completes.
    public func getApplications() -> IG.Database.Publishers.Discrete<[IG.Database.Application]> {
        self.database.publisher { _ in
                "SELECT * FROM \(IG.Database.Application.tableName)"
            }.read { (sqlite, statement, query, _) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                
                var result: [IG.Database.Application] = .init()
                while true {
                    switch sqlite3_step(statement).result {
                    case .row:  result.append(.init(statement: statement!))
                    case .done: return result
                    case let e: throw IG.Database.Error.callFailed(.querying(IG.Database.Application.self), code: e)
                    }
                }
            }.mapError(IG.Database.Error.transform)
            .eraseToAnyPublisher()
    }

    /// Returns the application specified by its API key.
    ///
    /// If the application is not found, an `.invalidResponse` is returned.
    /// - parameter key: The API key identifying the application.
    public func getApplication(key: IG.API.Key) -> IG.Database.Publishers.Discrete<IG.Database.Application> {
        self.database.publisher { _ in
                "SELECT * FROM Apps where key = ?1"
            }.read { (sqlite, statement, query, _) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                try sqlite3_bind_text(statement, 1, key.rawValue, -1, SQLite.Destructor.transient).expects(.ok) { .callFailed(.bindingAttributes, code: $0) }
                
                switch sqlite3_step(statement).result {
                case .row:  return .init(statement: statement!)
                case .done: throw IG.Database.Error.invalidResponse(.valueNotFound, suggestion: .valueNotFound)
                case let e: throw IG.Database.Error.callFailed(.querying(IG.Database.Application.self), code: e)
                }
            }.mapError(IG.Database.Error.transform)
            .eraseToAnyPublisher()
    }

    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter applications: Information returned from the server.
    public func update(applications: [IG.API.Application]) -> IG.Database.Publishers.Discrete<Never> {
        self.database.publisher { _ in
            """
            INSERT INTO \(IG.Database.Application.tableName) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, CURRENT_TIMESTAMP)
                ON CONFLICT(key) DO UPDATE SET
                    name = excluded.name, status = excluded.status,
                    equity = excluded.equity, quote = excluded.quote,
                    liApp = excluded.liApp, liAcco = excluded.liAcco, liTrade = excluded.liTrade, liHisto = excluded.liHisto, subs = excluded.subs,
                    created = excluded.created, updated = excluded.updated
            """
        }.write { (sqlite, statement, query, _) in
            try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
            
            for app in applications {
                IG.Database.Application(key: app.key, name: app.name, status: .init(app.status),
                                  permission: .init(accessToEquityPrices: app.permission.accessToEquityPrices,
                                                    areQuoteOrdersAllowed: app.permission.areQuoteOrdersAllowed),
                                  allowance: .init(overallRequests: app.allowance.overallRequests,
                                                   account: .init(overallRequests: app.allowance.account.overallRequests,
                                                                  tradingRequests: app.allowance.account.tradingRequests,
                                                                  historicalDataRequests: app.allowance.account.historicalDataRequests),
                                                   concurrentSubscriptions: app.allowance.subscriptionsLimit),
                                  created: app.creationDate,
                                  updated: Date())
                    .bind(to: statement!)

                try sqlite3_step(statement).expects(.done) { .callFailed(.storing(IG.Database.Application.self), code: $0) }
                sqlite3_clear_bindings(statement)
                sqlite3_reset(statement)
            }
        }.ignoreOutput()
        .mapError(IG.Database.Error.transform)
        .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.Database {
    /// Client application
    public struct Application {
        /// Application API key identifying the application and the developer.
        public let key: IG.API.Key
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

extension IG.Database.Application {
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

extension IG.Database.Application: DBTable {
    internal static let tableName: String = "Apps"
    internal static var tableDefinition: String {
        """
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

fileprivate extension IG.Database.Application {
    typealias Indices = (key: Int32, name: Int32, status: Int32, permission: Self.Permission.Indices, allowance: Self.Allowance.Indices, created: Int32, updated: Int32)
    
    init(statement s: SQLite.Statement, indices: Self.Indices = (0, 1, 2, (3, 4), (5, (6, 7, 8), 9), 10, 11)) {
        self.key = IG.API.Key(rawValue: String(cString: sqlite3_column_text(s, indices.key)))!
        self.name = String(cString: sqlite3_column_text(s, indices.name))
        self.status = Self.Status(rawValue: sqlite3_column_int(s, indices.status))!
        self.permission = .init(statement: s, indices: indices.permission)
        self.allowance = .init(statement: s, indices: indices.allowance)
        self.created = IG.Database.Formatter.date.date(from: String(cString: sqlite3_column_text(s, indices.created)))!
        self.updated = IG.Database.Formatter.timestamp.date(from: String(cString: sqlite3_column_text(s, indices.updated)))!
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices = (1, 2, 3, (4, 5), (6, (7, 8, 9), 10), 11, 12)) {
        sqlite3_bind_text(statement, indices.key,    self.key.rawValue, -1, SQLite.Destructor.transient)
        sqlite3_bind_text(statement, indices.name,   self.name, -1, SQLite.Destructor.transient)
        sqlite3_bind_int (statement, indices.status, status.rawValue)
        self.permission.bind(to: statement, indices: indices.permission)
        self.allowance.bind(to: statement, indices: indices.allowance)
        sqlite3_bind_text(statement, indices.created, IG.Database.Formatter.date.string(from: self.created), -1, SQLite.Destructor.transient)
    }   // Updated is not written for now.
}

fileprivate extension IG.Database.Application.Permission {
    typealias Indices = (equity: Int32, quotes: Int32)
    
    init(statement s: SQLite.Statement, indices: Self.Indices) {
        self.accessToEquityPrices = Bool(sqlite3_column_int(s, indices.equity))
        self.areQuoteOrdersAllowed = Bool(sqlite3_column_int(s, indices.quotes))
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices) {
        sqlite3_bind_int(statement, indices.equity, Int32(self.accessToEquityPrices))
        sqlite3_bind_int(statement, indices.quotes, Int32(self.areQuoteOrdersAllowed))
    }
}

fileprivate extension IG.Database.Application.Allowance {
    typealias Indices = (overall: Int32, account: Self.Account.Indices, subs: Int32)
    
    init(statement s: SQLite.Statement, indices: Self.Indices) {
        self.overallRequests = Int(sqlite3_column_int(s, indices.overall))
        self.account = .init(statement: s, indices: indices.account)
        self.concurrentSubscriptions = Int(sqlite3_column_int(s, indices.subs))
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices) {
        sqlite3_bind_int(statement, indices.overall, Int32(self.overallRequests))
        self.account.bind(to: statement, indices: indices.account)
        sqlite3_bind_int(statement, indices.subs, Int32(self.concurrentSubscriptions))
    }
}

fileprivate extension IG.Database.Application.Allowance.Account {
    typealias Indices = (overall: Int32, trading: Int32, historical: Int32)
    
    init(statement s: SQLite.Statement, indices: Self.Indices) {
        self.overallRequests = Int(sqlite3_column_int(s, indices.overall))
        self.tradingRequests = Int(sqlite3_column_int(s, indices.trading))
        self.historicalDataRequests = Int(sqlite3_column_int(s, indices.historical))
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices) {
        sqlite3_bind_int(statement, indices.overall,    Int32(self.overallRequests))
        sqlite3_bind_int(statement, indices.trading,    Int32(self.tradingRequests))
        sqlite3_bind_int(statement, indices.historical, Int32(self.historicalDataRequests))
    }
}

// MARK: API

fileprivate extension IG.Database.Application.Status {
    init(_ status: IG.API.Application.Status) {
        switch status {
        case .enabled:  self = .enabled
        case .disabled: self = .disabled
        case .revoked:  self = .revoked
        }
    }
}

// MARK: Debugging

extension IG.Database.Application: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.Database.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("key", self.key)
        result.append("name", self.name)
        let status: String
        switch self.status {
        case .enabled: status = "Enabled"
        case .disabled: status = "Disabled"
        case .revoked: status = "Revoked"
        }
        result.append("status", status)
        result.append("permission", self.permission) {
            $0.append("access to equities", $1.accessToEquityPrices)
            $0.append("quote orders allowed", $1.areQuoteOrdersAllowed)
        }
        result.append("allowance", self.allowance) {
            $0.append("overall requests", $1.overallRequests)
            $0.append("account", $1.account) {
                $0.append("overall requests", $1.overallRequests)
                $0.append("trading requests", $1.tradingRequests)
                $0.append("price requests", $1.historicalDataRequests)
            }
            $0.append("concurrent subscription limit", $1.concurrentSubscriptions)
        }
        result.append("created", self.created, formatter: IG.Database.Formatter.date)
        result.append("updated", self.updated, formatter: IG.Database.Formatter.timestamp.deepCopy(timeZone: .current))
        return result.generate()
    }
}
