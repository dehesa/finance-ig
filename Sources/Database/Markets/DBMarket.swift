import GRDB
import Foundation

extension IG.DB {
    /// List of all markets within the IG platform.
    public struct Market: GRDB.FetchableRecord {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// The type of market (i.e. instrument type).
        public let type: Self.Kind?
        
        public init(row: Row) {
            self.epic = row[0]
            self.type = row[1]
        }
    }
}

extension IG.DB.Market {
    /// The type of market (i.e. instrument type).
    public enum Kind: Int, GRDB.DatabaseValueConvertible {
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
    }
}

// MARK: - GRDB functionality

extension IG.DB.Market {
    static func tableCreation(in db: GRDB.Database) throws {
        try db.create(table: "markets", ifNotExists: false, withoutRowID: true) { (t) in
            t.column("epic", .text).primaryKey()
            t.column("type", .integer).indexed()
        }
    }
}

extension IG.DB.Market: GRDB.TableRecord {
    /// The table columns
    private enum Columns: String, GRDB.ColumnExpression {
        case epic = "epic"
        case type = "kind"
    }
    
    public static var databaseTableName: String {
        return "markets"
    }
    
    //public static var databaseSelection: [SQLSelectable] { [AllColumns()] }
}

extension IG.DB.Market: GRDB.PersistableRecord {
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.epic] = self.epic
        container[Columns.type] = self.type
    }
}
