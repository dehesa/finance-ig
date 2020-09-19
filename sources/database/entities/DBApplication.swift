import Foundation
import SQLite3

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

// MARK: -

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

internal extension Database.Application {
    typealias Indices = (key: Int32, name: Int32, status: Int32, permission: Self.Permission.Indices, allowance: Self.Allowance.Indices, created: Int32, updated: Int32)
    
    init(statement s: SQLite.Statement, indices: Indices = (0, 1, 2, (3, 4), (5, (6, 7, 8), 9), 10, 11)) {
        self.key = API.Key(String(cString: sqlite3_column_text(s, indices.key)))!
        self.name = String(cString: sqlite3_column_text(s, indices.name))
        self.status = Self.Status(rawValue: sqlite3_column_int(s, indices.status))!
        self.permission = .init(statement: s, indices: indices.permission)
        self.allowance = .init(statement: s, indices: indices.allowance)
        self.created = DateFormatter.date.date(from: String(cString: sqlite3_column_text(s, indices.created)))!
        self.updated = DateFormatter.timestamp.date(from: String(cString: sqlite3_column_text(s, indices.updated)))!
    }
    
    func _bind(to statement: SQLite.Statement, indices: Indices = (1, 2, 3, (4, 5), (6, (7, 8, 9), 10), 11, 12)) {
        sqlite3_bind_text(statement, indices.key,    self.key.description, -1, SQLite.Destructor.transient)
        sqlite3_bind_text(statement, indices.name,   self.name, -1, SQLite.Destructor.transient)
        sqlite3_bind_int (statement, indices.status, status.rawValue)
        self.permission._bind(to: statement, indices: indices.permission)
        self.allowance._bind(to: statement, indices: indices.allowance)
        sqlite3_bind_text(statement, indices.created, DateFormatter.date.string(from: self.created), -1, SQLite.Destructor.transient)
    } // Updated is not written for now.
}

internal extension Database.Application.Permission {
    typealias Indices = (equity: Int32, quotes: Int32)
    
    fileprivate init(statement s: SQLite.Statement, indices: Indices) {
        self.accessToEquityPrices = Bool(sqlite3_column_int(s, indices.equity))
        self.areQuoteOrdersAllowed = Bool(sqlite3_column_int(s, indices.quotes))
    }
    
    fileprivate func _bind(to statement: SQLite.Statement, indices: Indices) {
        sqlite3_bind_int(statement, indices.equity, Int32(self.accessToEquityPrices))
        sqlite3_bind_int(statement, indices.quotes, Int32(self.areQuoteOrdersAllowed))
    }
}

internal extension Database.Application.Allowance {
    typealias Indices = (overall: Int32, account: Self.Account.Indices, subs: Int32)
    
    fileprivate init(statement s: SQLite.Statement, indices: Indices) {
        self.overallRequests = Int(sqlite3_column_int(s, indices.overall))
        self.account = .init(statement: s, indices: indices.account)
        self.concurrentSubscriptions = Int(sqlite3_column_int(s, indices.subs))
    }
    
    fileprivate func _bind(to statement: SQLite.Statement, indices: Indices) {
        sqlite3_bind_int(statement, indices.overall, Int32(self.overallRequests))
        self.account._bind(to: statement, indices: indices.account)
        sqlite3_bind_int(statement, indices.subs, Int32(self.concurrentSubscriptions))
    }
}

internal extension Database.Application.Allowance.Account {
    typealias Indices = (overall: Int32, trading: Int32, historical: Int32)
    
    fileprivate init(statement s: SQLite.Statement, indices: Indices) {
        self.overallRequests = Int(sqlite3_column_int(s, indices.overall))
        self.tradingRequests = Int(sqlite3_column_int(s, indices.trading))
        self.historicalDataRequests = Int(sqlite3_column_int(s, indices.historical))
    }
    
    fileprivate func _bind(to statement: SQLite.Statement, indices: Indices) {
        sqlite3_bind_int(statement, indices.overall,    Int32(self.overallRequests))
        sqlite3_bind_int(statement, indices.trading,    Int32(self.tradingRequests))
        sqlite3_bind_int(statement, indices.historical, Int32(self.historicalDataRequests))
    }
}

internal extension Database.Application.Status {
    init(_ status: API.Application.Status) {
        switch status {
        case .enabled:  self = .enabled
        case .disabled: self = .disabled
        case .revoked:  self = .revoked
        }
    }
}
