import ReactiveSwift
import Foundation

extension IG.DB.Request.Markets {
    /// Returns all markets stored in the database.
//    public func getAll() -> SignalProducer<[IG.DB.Market],IG.DB.Error> {
//        SignalProducer(database: self.database)
//            .read { (db, _, _) in
//                try IG.DB.Market.fetchAll(db)
//            }
//    }
    
    ///
//    public func update(_ market: [IG.API.Market]) {
//        SignalProducer(database: self.database) { _ in
//            
//        }
//    }
}

// MARK: - Supporting Entities

extension IG.DB.Request {
    /// Contains all functionality related to API applications.
    public struct Markets {
        /// Pointer to the actual database instance in charge of the low-level objects.
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
    /// List of all markets within the IG platform.
    public struct Market {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// The type of market (i.e. instrument type).
        public let type: Self.Kind?
        
//        public init(row: Row) {
//            self.epic = row[0]
//            self.type = row[1]
//        }
    }
}

extension IG.DB.Market {
    /// The type of market (i.e. instrument type).
    public enum Kind: Int, CustomDebugStringConvertible {
        /// Bonds, money markets, etc.
        case rates = 1
        /// Shares are unit of ownership interest in a corporation or financial asset that provide for an equal distribution in any profits, if any are declared, in the form of dividends.
        case shares = 2
        /// An index is an statistical measure of change in a securities market.
        case indices = 3
        /// Commodities are hard assets ranging from wheat to gold to oil.
        case commodities = 4
        /// Currencies are medium of exchange.
        case currencies = 5
        /// An option is a contract which gives the buyer the right, but not the obligation, to buy or sell an underlying asset or instrument at a specified strike price prior to or on a specified date, depending on the form of the option.
        case options = 6
        
        public var debugDescription: String {
            switch self {
            case .rates: return "rates"
            case .shares: return "shares"
            case .indices: return "indices"
            case .commodities: return "commodities"
            case .currencies: return "currencies"
            case .options: return "options"
            }
        }
    }
}

// MARK: - GRDB functionality

//extension IG.DB.Market {
//    static func tableCreation(in db: GRDB.Database) throws {
//        try db.create(table: "markets", ifNotExists: false, withoutRowID: true) { (t) in
//            t.column("epic", .text).primaryKey()
//            t.column("type", .integer).indexed()
//        }
//    }
//}
//
//extension IG.DB.Market: GRDB.TableRecord {
//    /// The table columns
//    private enum Columns: String, GRDB.ColumnExpression {
//        case epic = "epic"
//        case type = "kind"
//    }
//
//    public static var databaseTableName: String {
//        return "markets"
//    }
//
//    //public static var databaseSelection: [SQLSelectable] { [AllColumns()] }
//}
//
//extension IG.DB.Market: GRDB.PersistableRecord {
//    public func encode(to container: inout PersistenceContainer) {
//        container[Columns.epic] = self.epic
//        container[Columns.type] = self.type
//    }
//}
