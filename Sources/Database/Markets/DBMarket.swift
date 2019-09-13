import ReactiveSwift
import Foundation
import SQLite3

extension IG.DB.Request.Markets {
    /// Returns all markets stored in the database.
    public func getAll() -> SignalProducer<[IG.DB.Market],IG.DB.Error> {
        return self.database.work { (channel, requestPermission) in
            var statement: SQLite.Statement? = nil
            defer { sqlite3_finalize(statement) }
            
            let query = "SELECT * FROM Markets;"
            if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
                return .failure(error: .callFailed(.querying(IG.DB.Market.self), code: compileError))
            }
            
            var result: [IG.DB.Market] = .init()
            repeat {
                switch sqlite3_step(statement).result {
                case .row:  result.append(.init(statement: statement!))
                case .done: return .success(value: result)
                case let e: return .failure(error: .callFailed(.querying(IG.DB.Market.self), code: e))
                }
            } while requestPermission().isAllowed
            
            return .interruption
        }
    }
    
    /// Updates the database with the information received from the server.
    /// - remark: If this function encounters an error in the middle of a transaction, it keeps the values stored right before the error.
    /// - parameter markets: Information returned from the server.
    public func update(_ markets: [IG.API.Market]) -> SignalProducer<Void,IG.DB.Error> {
        return self.database.work { (channel, requestPermission) in
            sqlite3_exec(channel, "BEGIN TRANSACTION", nil, nil, nil)
            defer { sqlite3_exec(channel, "END TRANSACTION", nil, nil, nil) }
            
            var statement: SQLite.Statement? = nil
            defer { sqlite3_finalize(statement) }
            
            let query = "INSERT INTO Markets VALUES(?1, ?2) ON CONFLICT(epic) DO NOTHING;"
            if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
                return .failure(error: .callFailed(.storing(IG.DB.Market.self), code: compileError, suggestion: .reviewError))
            }
            
            for market in markets {
                guard case .continue = requestPermission() else { return .interruption }
                sqlite3_reset(statement)
                sqlite3_bind_text(statement, 1, market.instrument.epic.rawValue, -1, SQLITE_TRANSIENT)
//                sqlite3_bind_int (statement, 2, Int32(market.instrument.type.rawValue))
                #warning("Continue developing here!")
                
                if let updateError = sqlite3_step(statement).enforce(.done) {
                    return .failure(error: .callFailed(.storing(IG.DB.Market.self), code: updateError))
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

// MARK: Response Entities

extension IG.DB {
    /// List of all markets within the IG platform.
    public struct Market {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// The type of market (i.e. instrument type).
        public let type: Self.Kind?
        
        /// Initializer when the instance comes directly from the database.
        fileprivate init(statement s: SQLite.Statement) {
            self.epic = IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(s, 0)))!
            self.type = Self.Kind(rawValue: Int(sqlite3_column_int(s, 1)))!
        }
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

extension IG.DB.Market: DBMigratable {
    internal static func tableDefinition(for version: DB.Migration.Version) -> String? {
        switch version {
        case .v0: return """
        CREATE TABLE Markets (
        epic TEXT    NOT NULL CHECK( LENGTH(epic) BETWEEN 6 AND 30 ),
        type INTEGER          CHECK( type BETWEEN 1 AND 6 ),
        PRIMARY KEY(epic)
        ) WITHOUT ROWID;
        """
        }
    }
}

extension IG.DB.Market: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return IG.DB.printableDomain.appending(".\(Self.self)")
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("epic", self.epic.rawValue)
        result.append("type", self.type.debugDescription)
        return result.generate()
    }
}
