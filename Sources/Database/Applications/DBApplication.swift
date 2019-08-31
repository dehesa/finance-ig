import GRDB
import Foundation

extension IG.DB {
    /// Client application
    public struct Application: GRDB.FetchableRecord {
        /// Application API key identifying the application and the developer.
        public let key: API.Key
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
        
        public init(row: GRDB.Row) {
            self.key = row[0]
            self.created = row[1]
            self.name = row[2]
            self.status = row[3]
            self.permission = .init(equities: row[4], quoteOrders: row[5])
            self.allowance = Self.Allowance(overall: row[6], account: row[7], trading: row[8], history: row[9], subscriptions: row[10])
            self.updated = row[11]
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

// MARK: - GRDB functionality

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

extension IG.DB.Application: GRDB.TableRecord {
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
    
    public static var databaseTableName: String {
        return "applications"
    }
    
    //public static var databaseSelection: [SQLSelectable] { [AllColumns()] }
}

extension IG.DB.Application: GRDB.PersistableRecord {
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
