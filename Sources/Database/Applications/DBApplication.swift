import ReactiveSwift
import Foundation
import SQLite3

extension IG.DB.Request.Applications {
    /// Returns all applications stored in the database.
    public func getAll() -> SignalProducer<[IG.DB.Application],IG.DB.Error> {
        return self.database.work { (channel, requestPermission) in
            var statement: SQLite.Statement? = nil
            defer { sqlite3_finalize(statement) }
            
            let query = "SELECT * FROM Apps;"
            if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
                return .failure(error: .callFailed(.querying(IG.DB.Application.self), code: compileError))
            }
            
            var result: [IG.DB.Application] = .init()
            repeat {
                switch sqlite3_step(statement).result {
                case .row:  result.append(.init(statement: statement!))
                case .done: return .success(value: result)
                case let e: return .failure(error: .callFailed(.querying(IG.DB.Application.self), code: e))
                }
            } while requestPermission().isAllowed
            
            return .interruption
        }
    }
    
    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter applications: Information returned from the server.
    public func update(_ applications: [IG.API.Application]) -> SignalProducer<Void,IG.DB.Error> {
        return self.database.work { (channel, requestPermission) in
            sqlite3_exec(channel, "BEGIN TRANSACTION", nil, nil, nil)
            defer { sqlite3_exec(channel, "END TRANSACTION", nil, nil, nil) }
            
            var statement: SQLite.Statement? = nil
            defer { sqlite3_finalize(statement) }
            
            let query = """
                INSERT INTO Apps VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, CURRENT_TIMESTAMP)
                    ON CONFLICT(key) DO UPDATE SET
                        name = excluded.name, status = excluded.status,
                        equity = excluded.equity, quote = excluded.quote,
                        liApp = excluded.liApp, liAcco = excluded.liAcco, liTrade = excluded.liTrade, liHisto = excluded.liHisto, subs = excluded.subs,
                        created = excluded.created, updated = excluded.updated;
                """
            if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
                return .failure(error: .callFailed(.storing(IG.DB.Application.self), code: compileError))
            }
            
            for app in applications {
                guard case .continue = requestPermission() else { return .interruption }
                sqlite3_reset(statement)
                
                let status: IG.DB.Application.Status
                switch app.status {
                case .enabled: status = .enabled
                case .disabled: status = .disabled
                case .revoked: status = .revoked
                }
                
                sqlite3_bind_text (statement, 1, app.key.rawValue, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text (statement, 2, app.name, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int  (statement, 3, status.rawValue)
                sqlite3_bind_int  (statement, 4, Int32(app.permission.accessToEquityPrices))
                sqlite3_bind_int  (statement, 5, Int32(app.permission.areQuoteOrdersAllowed))
                sqlite3_bind_int64(statement, 6, Int64(app.allowance.overallRequests))
                sqlite3_bind_int64(statement, 7, Int64(app.allowance.account.overallRequests))
                sqlite3_bind_int64(statement, 8, Int64(app.allowance.account.tradingRequests))
                sqlite3_bind_int64(statement, 9, Int64(app.allowance.account.historicalDataRequests))
                sqlite3_bind_int64(statement,10, Int64(app.allowance.subscriptionsLimit))
                sqlite3_bind_text (statement,11, IG.DB.Formatter.date.string(from: app.creationDate), -1, SQLITE_TRANSIENT)
                
                if let updateError = sqlite3_step(statement).enforce(.done) {
                    return .failure(error: .callFailed(.storing(IG.DB.Application.self), code: updateError))
                }
                
                sqlite3_clear_bindings(statement)
            }
            
            return .success(value: ())
        }
    }
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

// MARK: Response Entities

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
        
        /// Initializer when the instance comes directly from the database.
        fileprivate init(statement s: SQLite.Statement) {
            self.key = IG.API.Key(rawValue: String(cString: sqlite3_column_text(s, 0)))!
            self.name = String(cString: sqlite3_column_text(s, 1))
            self.status = Self.Status(rawValue: sqlite3_column_int(s, 2))!
            self.permission = .init(equities: Bool(sqlite3_column_int(s, 3)),
                                    quoteOrders: Bool(sqlite3_column_int(s, 4)))
            self.allowance = .init(overall: Int(sqlite3_column_int64(s, 5)),
                                   account: Int(sqlite3_column_int64(s, 6)),
                                   trading: Int(sqlite3_column_int64(s, 7)),
                                   history: Int(sqlite3_column_int64(s, 8)),
                                   subscriptions: Int(sqlite3_column_int64(s, 9)))
            self.created = IG.DB.Formatter.date.date(from: String(cString: sqlite3_column_text(s, 10)))!
            self.updated = IG.DB.Formatter.timestamp.date(from: String(cString: sqlite3_column_text(s, 11)))!
        }
    }
}

extension IG.DB.Application {
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

extension IG.DB.Application: DBMigratable {
    internal static func tableDefinition(for version: IG.DB.Migration.Version) -> String? {
        switch version {
        case .v0: return """
            CREATE TABLE Apps (
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
}

extension IG.DB.Application: IG.DebugDescriptable {
    static var printableDomain: String {
        return IG.DB.printableDomain.appending(".\(Self.self)")
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
        result.append("created", self.created, formatter: IG.Formatter.date(time: nil))
        result.append("updated", self.updated, formatter: IG.Formatter.date(localize: true))
        return result.generate()
    }
}
