import GRDB
import ReactiveSwift
import Foundation

extension IG.DB.Request.Applications {
    /// Returns all applications stored in the database.
    public func getAll() -> SignalProducer<[IG.DB.Application],IG.DB.Error> {
        SignalProducer(database: self.database)
            .read { (db, _, _) in
                try IG.DB.Application.fetchAll(db)
            }
    }
    
    /// Updates the database with the information received from the server.
    /// - parameter applications: Information returned from the server.
    /// - throws: `Database.Error` exclusively.
    public func update(_ applications: [IG.API.Application]) -> SignalProducer<Void,IG.DB.Error> {
        SignalProducer(database: self.database) { _ in
                applications.map { IG.DB.Application(with: $0) }
            }.write { (db, applications, shallContinue) -> Void in
                for app in applications {
                    guard case .continue = shallContinue() else { return }
                    try app.save(db)
                }
            }
    }
}

// MARK: - Supporting Entities

extension IG.DB.Request {
    /// Contains all functionality related to API applications.
    public struct Applications {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        fileprivate unowned let database: IG.DB
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
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
        /// Application creation date (referencing UTC dates, although no time data is stored).
        public let created: Date
        /// Application name given by the developer.
        public let name: String
        ///  Application status.
        public let status: Self.Status
        /// What the platform allows the application or account to do (e.g. requests per minute).
        public let permission: Self.Permission
        /// The limits at which the receiving application is constrained to.
        public let allowance: Self.Allowance
        /// The date at which this entity was inserted in the database with factual information.
        public let updated: Date
        
        fileprivate init(with app: IG.API.Application) {
            self.key = app.key
            self.created = app.creationDate
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
            self.updated = Date()
        }
    }
}

extension IG.DB.Application {
    /// Application status in the platform.
    public enum Status: Int, GRDB.DatabaseValueConvertible {
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

// MARK: GRDB functionality

extension IG.DB.Application {
    /// Creates a SQLite table for API applications.
    static func tableCreation(in db: GRDB.Database) throws {
        try db.create(table: "applications", ifNotExists: false, withoutRowID: true) { (t) in
            t.column("key", .text).primaryKey()
            t.column("created", .date).notNull()
            t.column("name", .text).notNull().collate(.unicodeCompare)
            t.column("status", .integer).notNull()
            t.column("allowEquities", .boolean).notNull()
            t.column("allowQuotes", .boolean).notNull()
            t.column("limitApp", .integer).notNull() 
            t.column("limitAccount", .integer).notNull()
            t.column("limitTrade", .integer).notNull()
            t.column("limitHistory", .integer).notNull()
            t.column("limitSubs", .integer).notNull()
            t.column("updated", .date).notNull()
        }
    }
}

extension IG.DB.Application: GRDB.FetchableRecord, GRDB.TableRecord, GRDB.PersistableRecord {
    /// The table columns
    private enum Columns: String, GRDB.ColumnExpression {
        case key = "key"
        case created = "created"
        case name = "name"
        case status = "status"
        case accessToEquityPrices = "allowEquities"
        case areQuoteOrdersAllowed = "allowQuotes"
        case appRequestsLimit = "limitApp"
        case accountRequestsLimit = "limitAccount"
        case tradeRequestsLimit = "limitTrade"
        case dataRequestsLimit = "limitHistory"
        case concurrentSubscriptionLimit = "limitSubs"
        case updated = "updated"
    }
    
    public init(row: GRDB.Row) {
        self.key = row[0]
        self.created = row[1]
        self.name = row[2]
        self.status = row[3]
        self.permission = .init(equities: row[4], quoteOrders: row[5])
        self.allowance = Self.Allowance(overall: row[6], account: row[7], trading: row[8], history: row[9], subscriptions: row[10])
        self.updated = row[11]
    }
    
    public static var databaseTableName: String {
        return "applications"
    }
    
    //public static var databaseSelection: [SQLSelectable] { [AllColumns()] }

    public func encode(to container: inout GRDB.PersistenceContainer) {
        container[Columns.key] = self.key
        container[Columns.created] = self.created
        container[Columns.name] = self.name
        container[Columns.status] = self.status
        container[Columns.accessToEquityPrices] = self.permission.accessToEquityPrices
        container[Columns.areQuoteOrdersAllowed] = self.permission.areQuoteOrdersAllowed
        container[Columns.appRequestsLimit] = self.allowance.overallRequests
        container[Columns.accountRequestsLimit] = self.allowance.account.overallRequests
        container[Columns.tradeRequestsLimit] = self.allowance.account.tradingRequests
        container[Columns.dataRequestsLimit] = self.allowance.account.historicalDataRequests
        container[Columns.concurrentSubscriptionLimit] = self.allowance.concurrentSubscriptions
        container[Columns.updated] = self.updated
    }
}
