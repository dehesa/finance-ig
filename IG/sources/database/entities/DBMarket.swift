import Foundation
import SQLite3

extension Database {
    /// List of all markets within the IG platform.
    public struct Market {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// The type of market (i.e. instrument type).
        public let type: Self.Kind?
    }
}

extension Database.Market {
    /// The type of market (i.e. instrument type).
    /// - todo: More will be added conforming support is rolled out.
    public enum Kind: RawRepresentable {
        /// Currencies are medium of exchange.
        case currencies(Self.Currency)
        /// An index is an statistical measure of change in a securities market.
        case indices
        
        public enum Currency {
            case forex
        }
    }
}

// MARK: -

extension Database.Market: DBTable {
    internal static let tableName: String = "Markets"
    
    internal static var tableDefinition: String { """
        CREATE TABLE \(Self.tableName) (
            epic  TEXT    NOT NULL CHECK( LENGTH(epic) BETWEEN 6 AND 30 ),
            type  INTEGER,
            
            PRIMARY KEY(epic)
        ) WITHOUT ROWID;
        """
    }
}

internal extension Database.Market {
    typealias Indices = (epic: Int32, type: Int32)
    
    init(statement s: SQLite.Statement, indices: Indices = (0, 1)) {
        self.epic = IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(s, indices.epic)))!
        self.type = Self.Kind(rawValue: sqlite3_column_int(s, indices.type))    // Implicit SQLite conversion from `NULL` to `0`
    }
    
    func _bind(to statement: SQLite.Statement, indices: Indices = (1, 2)) {
        sqlite3_bind_text(statement, indices.epic, self.epic.rawValue, -1, SQLite.Destructor.transient)
        self.type.unwrap( none: { sqlite3_bind_null(statement, indices.type) },
                          some: { sqlite3_bind_int (statement, indices.type, $0.rawValue) })
    }
}

// MARK: API

extension Database.Market.Kind: Equatable {
    public init?(rawValue: Int32) {
        typealias V = _Value
        switch rawValue {
        case 0: return nil
        case V.currenciesForex:  self = .currencies(.forex)
        case V.indices:          self = .indices
        default: return nil
        }
    }
    
    internal init?(market: API.Market) {
        switch market.instrument.type {
        case .currencies where Database.Market.Forex.isCompatible(market: market): self = .currencies(.forex)
//        case .indices:     self = .indices
//        case .rates:       self = .rates
//        case .options:     self = .options
//        case .shares:      self = .shares
//        case .commodities: self = .commodities
        default: return nil
        }
    }
    
    public var rawValue: Int32 {
        typealias V = _Value
        switch self {
        case .currencies(.forex):  return V.currenciesForex
        case .indices:             return V.indices
        }
    }
    
    private enum _Value {
        static let currencies:       Int32 = 1
        static let currenciesForex:  Int32 = Self.currencies | (1 << 16)
        static let indices:          Int32 = 2
    }
}
