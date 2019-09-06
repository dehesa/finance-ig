import SQLite3
import ReactiveSwift
import Foundation

extension IG.DB.Request.Applications {
//    /// Returns all applications stored in the database.
//    public func getAll() -> SignalProducer<[IG.DB.Application],IG.DB.Error> {
//        SignalProducer(database: self.database)
//            .read { (db, _, _) in
//                try IG.DB.Application.fetchAll(db)
//            }
//    }

    /// Updates the database with the information received from the server.
    /// - parameter applications: Information returned from the server.
    /// - throws: `Database.Error` exclusively.
//    public func update(_ applications: [IG.API.Application]) -> SignalProducer<Void,IG.DB.Error> {
//        typealias C = IG.DB.Application.Columns
//        typealias A = IG.API.Application
//
//        return SignalProducer(database: self.database).write { (db, _, shallContinue) -> Void in
//            for app in applications {
//                guard case .continue = shallContinue() else { return }
////                try db.execute(sql: "INSERT OR REPLACE INTO \(IG.DB.Application.tableName) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);")
//                let pointer = db.sqliteConnection
////                sqlite3_prepare_v2(pointer, <#T##zSql: UnsafePointer<Int8>!##UnsafePointer<Int8>!#>, <#T##nByte: Int32##Int32#>, <#T##ppStmt: UnsafeMutablePointer<OpaquePointer?>!##UnsafeMutablePointer<OpaquePointer?>!#>, <#T##pzTail: UnsafeMutablePointer<UnsafePointer<Int8>?>!##UnsafeMutablePointer<UnsafePointer<Int8>?>!#>)
//                sqlite3_bind_text(pointer, <#T##Int32#>, <#T##UnsafePointer<Int8>!#>, <#T##Int32#>, <#T##((UnsafeMutableRawPointer?) -> Void)!##((UnsafeMutableRawPointer?) -> Void)!##(UnsafeMutableRawPointer?) -> Void#>)
//                sqlite3_bind_text(pointer, <#T##Int32#>, <#T##UnsafePointer<Int8>!#>, <#T##Int32#>, <#T##((UnsafeMutableRawPointer?) -> Void)!##((UnsafeMutableRawPointer?) -> Void)!##(UnsafeMutableRawPointer?) -> Void#>)
//                sqlite3_step
//            }
//        }
//    }
}

// MARK: - Supporting Entities

extension IG.DB.Request {
    /// Contains all functionality related to API applications.
    public struct Applications {
        /// Pointer to the actual database instance in charge of the low-level objects..
        fileprivate unowned let database: IG.DB
        
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        /// - parameter database: The instance calling the low-level databse.
        init(database: IG.DB) {
            self.database = database
        }
    }
}

// MARK: Request Entities

extension IG.DB {
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
        
        /// Mapper from API instances to DB instances.
        fileprivate init(with app: IG.API.Application) {
            self.key = app.key
            self.name = app.name
            
            switch app.status {
            case .enabled:  self.status = .enabled
            case .disabled: self.status = .disabled
            case .revoked:  self.status = .revoked
            }
            
            self.permission = .init(equities: app.permission.accessToEquityPrices, quoteOrders: app.permission.areQuoteOrdersAllowed)
            self.allowance = .init(overall: app.allowance.overallRequests,
                                   account: app.allowance.account.overallRequests,
                                   trading: app.allowance.account.tradingRequests,
                                   history: app.allowance.account.tradingRequests,
                                   subscriptions: app.allowance.subscriptionsLimit)
            self.created = app.creationDate
            self.updated = Date()
        }
    }
}

extension IG.DB.Application {
    /// Application status in the platform.
    public enum Status: Int {
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
        /// Designated initializer.
        fileprivate init(equities: Bool, quoteOrders: Bool) {
            self.accessToEquityPrices = equities
            self.areQuoteOrdersAllowed = quoteOrders
        }
    }
    
    /// The restrictions constraining an API application.
    public struct Allowance {
        /// Overal application request per minute allowance.
        public let overallRequests: Int
        /// Account related requests per minute allowance.
        public let account: Self.Account
        /// Concurrent subscriptioon limit per lightstreamer connection.
        public let concurrentSubscriptions: Int
        /// Designated initializer.
        fileprivate init(overall: Int, account: Int, trading: Int, history: Int, subscriptions: Int) {
            self.overallRequests = overall
            self.account = .init(account: account, trading: trading, history: history)
            self.concurrentSubscriptions = subscriptions
        }
        
        /// Limit and allowances for the targeted account.
        public struct Account {
            /// Per account request per minute allowance.
            public let overallRequests: Int
            /// Per account trading request per minute allowance.
            public let tradingRequests: Int
            /// Historical price data data points per minute allowance.
            public let historicalDataRequests: Int
            /// Designated initializer.
            fileprivate init(account: Int, trading: Int, history: Int) {
                self.overallRequests = account
                self.tradingRequests = trading
                self.historicalDataRequests = history
            }
        }
    }
}

extension IG.DB.Application {
    /// Creates a SQLite table for API applications.
    internal static func tableDefinition(for version: IG.DB.Migration.Version) -> String? {
        #warning("Specify default unicode collations for 'name'")
        switch version {
        case .v0: return """
            CREATE TABLE Apps (
            key     TEXT     NOT NULL CHECK ( LENGTH(name) > 0 ) PRIMARY KEY,
            name    TEXT     NOT NULL CHECK ( LENGTH(name) > 0 ),
            status  INTEGER  NOT NULL CHECK ( status BETWEEN -1 AND 1 ),
            equity  BOOLEAN  NOT NULL CHECK ( equity BETWEEN 0 AND 1 ),
            quote   BOOLEAN  NOT NULL CHECK ( quote BETWEEN 0 AND 1 ),
            liApp   INTEGER  NOT NULL CHECK ( liApp >= 0 ),
            liAcco  INTEGER  NOT NULL CHECK ( liAcco >= 0 ),
            liTrade INTEGER  NOT NULL CHECK ( liTrade >= 0 ),
            liHisto INTEGER  NOT NULL CHECK ( liHisto >= 0 ),
            subs    INTEGER  NOT NULL CHECK ( subs >= 0 ),
            created TEXT     NOT NULL CHECK (( created IS DATE(created) ) AND ( created <= DATE('now') )),
            updated TEXT     NOT NULL DEFAULT CURRENT_TIMESTAMP CHECK (( created IS DATE(created) ) AND ( updated <= CURRENT_TIMESTAMP ))
            ) WITHOUT ROWID;
            """
        }
    }
    
    /// The table name for the latest supported migration.
    fileprivate static var tableName: String {
        return "Apps"
    }
    
    /// The table columns for the latest supported migration.
    fileprivate enum Columns: String {
        case key                    = "key"
        case name                   = "name"
        case status                 = "status"
        case accessToEquityPrices   = "equity"
        case areQuoteOrdersAllowed  = "quote"
        case appRequestsLimit       = "liApp"
        case accountRequestsLimit   = "liAcco"
        case tradeRequestsLimit     = "liTrade"
        case dataRequestsLimit      = "liHisto"
        case concurrentSubscriptionLimit = "subs"
        case created                = "created"
        case updated                = "updated"
    }

//    public init(row: GRDB.Row) {
//        self.key = row[0]
//        self.name = row[1]
//        self.status = row[2]
//        self.permission = .init(equities: row[3], quoteOrders: row[4])
//        self.allowance = Self.Allowance(overall: row[5], account: row[6], trading: row[7], history: row[8], subscriptions: row[9])
//        self.created = row[10]
//        self.updated = row[11]
//    }
//
//    public func encode(to container: inout GRDB.PersistenceContainer) {
//        container[Columns.key] = self.key
//        container[Columns.created] = self.created
//        container[Columns.name] = self.name
//        container[Columns.status] = self.status
//        container[Columns.accessToEquityPrices] = self.permission.accessToEquityPrices
//        container[Columns.areQuoteOrdersAllowed] = self.permission.areQuoteOrdersAllowed
//        container[Columns.appRequestsLimit] = self.allowance.overallRequests
//        container[Columns.accountRequestsLimit] = self.allowance.account.overallRequests
//        container[Columns.tradeRequestsLimit] = self.allowance.account.tradingRequests
//        container[Columns.dataRequestsLimit] = self.allowance.account.historicalDataRequests
//        container[Columns.concurrentSubscriptionLimit] = self.allowance.concurrentSubscriptions
//        container[Columns.updated] = self.updated
//    }
}

extension IG.DB.Application: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = IG.DebugDescription("DB Application")
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
        result.append("created", self.created, formatter: IG.Formatter.date(time: nil))
        result.append("updated", self.updated, formatter: IG.Formatter.date(localize: true))
        return result.generate()
    }
}
