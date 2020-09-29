import Foundation
import Decimals
import SQLite3

extension Database {
    /// Historical central bank interest rate.
    public struct InterestRate {
        /// Indication of the year/month/day (for UTC) when the rate was changed.
        public let date: Date
        /// The currency code identifying the country/central bank.
        public let currency: Currency.Code
        /// The value for the interest rate at the given date.
        public let rate: Decimal64
    }
}

extension Database.InterestRate: DBTable {
    internal static let tableName: String = "InterestRates"
    
    internal static var tableDefinition: String { """
        CREATE TABLE '\(Self.tableName)' (
            date     TEXT    NOT NULL CHECK( date IS DATE(date) ),
            currency TEXT    NOT NULL CHECK( LENGTH(currency) == 3 ),
            rate     INTEGER NOT NULL,

            CONSTRAINT pk_CurInterest PRIMARY KEY (date,currency)
        ) WITHOUT ROWID;
        """
    }
}


internal extension Database.InterestRate {
    typealias Indices = (date: Int32, rate: Int32, currency: Int32)
    private static let powerOf10: Int = 3
    
    init(statement s: SQLite.Statement, formatter: UTC.Day, indices: Indices = (0, 1, 2)) {
        self.date = formatter.date(from: String(cString: sqlite3_column_text(s, indices.date)))
        self.rate = Decimal64(.init(sqlite3_column_int(s, indices.rate)), power: -Self.powerOf10)!
        self.currency = Currency.Code(String(cString: sqlite3_column_text(s, indices.currency)))!
    }
    
    func _bind(to statement: SQLite.Statement, indices: Indices = (1, 2, 3)) {
        sqlite3_bind_text(statement, indices.date, UTC.Day.string(from: self.date), -1, SQLite.Destructor.transient)
        sqlite3_bind_int(statement, indices.rate, Int32(clamping: self.rate << Self.powerOf10))
        sqlite3_bind_text(statement, indices.currency, self.currency.description, -1, SQLite.Destructor.transient)
    }
}
