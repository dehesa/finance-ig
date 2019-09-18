import ReactiveSwift
import Foundation
import SQLite3

extension IG.DB.Request {
    /// Contains all functionality related to DB markets.
    public struct Markets {
        /// Pointer to the actual database instance in charge of the low-level objects.
        fileprivate unowned let database: IG.DB
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        internal init(database: IG.DB) { self.database = database }
        
        /// It holds data and functionality related to the forex markets.
        public var forex: IG.DB.Request.Markets.Forex { return .init(database: self.database) }
    }
}

extension IG.DB.Request.Markets {
    /// Returns all markets stored in the database.
    ///
    /// Only the epic and the type of markets are returned.
    public func getAll() -> SignalProducer<[IG.DB.Market],IG.DB.Error> {
        return self.database.work { (channel, requestPermission) in
            var statement: SQLite.Statement? = nil
            defer { sqlite3_finalize(statement) }
            
            let query = "SELECT * FROM \(IG.DB.Market.tableName)"
            if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
                return .failure(.callFailed(.compilingSQL, code: compileError))
            }
            
            var result: [IG.DB.Market] = .init()
            repeat {
                switch sqlite3_step(statement).result {
                case .row:  result.append(.init(statement: statement!))
                case .done: return .success(result)
                case let e: return .failure(.callFailed(.querying(IG.DB.Market.self), code: e))
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
            let query = """
                INSERT INTO \(IG.DB.Market.tableName) VALUES(?1, ?2, ?3)
                    ON CONFLICT(epic) DO UPDATE SET type=excluded.type
                """
            if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
                return .failure(.callFailed(.compilingSQL, code: compileError))
            }
            
            for apiMarket in markets {
                guard case .continue = requestPermission() else { return .interruption }
                
                let dbMarket = IG.DB.Market(epic: apiMarket.instrument.epic, type: IG.DB.Market.Kind(market: apiMarket), price: nil)
                dbMarket.bind(to: statement!)
                
                if let updateError = sqlite3_step(statement).enforce(.done) {
                    return .failure(.callFailed(.storing(IG.DB.Market.self), code: updateError))
                }
                
                sqlite3_clear_bindings(statement)
                sqlite3_reset(statement)
            }
            
            return Self.Forex.update(forexMarkets: markets, continueOnError: true, channel: channel, permission: requestPermission)
        }
    }
}

// MARK: - Entities

extension IG.DB {
    /// List of all markets within the IG platform.
    public struct Market {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// The type of market (i.e. instrument type).
        public let type: Self.Kind?
        /// The name of the price table.
        public let price: String?
    }
}

extension IG.DB.Market {
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

// MARK: - Functionality

// MARK: SQLite

extension IG.DB.Market: DBTable {
    internal static let tableName: String = "Markets"
    internal static var tableDefinition: String {
        """
        CREATE TABLE \(Self.tableName) (
            epic  TEXT    NOT NULL CHECK( LENGTH(epic) BETWEEN 6 AND 30 ),
            type  INTEGER,
            price TEXT    UNIQUE   CHECK( LENGTH(price) > 3 ),
            
            PRIMARY KEY(epic)
        ) WITHOUT ROWID;
        """
    }
}

fileprivate extension IG.DB.Market {
    typealias Indices = (epic: Int32, type: Int32, price: Int32)
    
    init(statement s: SQLite.Statement, indices: Self.Indices = (0, 1, 2)) {
        self.epic = IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(s, indices.epic)))!
        self.type = Self.Kind(rawValue: sqlite3_column_int(s, indices.type))    // Implicit SQLite conversion from `NULL` to `0`
        self.price = sqlite3_column_text(s, indices.price).map { String(cString: $0) }
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices = (1, 2, 3)) {
        sqlite3_bind_text(statement, indices.epic, self.epic.rawValue, -1, SQLITE_TRANSIENT)
        self.type.unwrap(none:  { sqlite3_bind_null(statement, indices.type) },
                         some:  { sqlite3_bind_int (statement, indices.type, $0.rawValue) })
        self.price.unwrap(none: { sqlite3_bind_null(statement, indices.price) },
                          some: { sqlite3_bind_text(statement, indices.price, $0, -1, SQLITE_TRANSIENT) })
    }
}

// MARK: API

extension IG.DB.Market.Kind {
    public init?(rawValue: Int32) {
        typealias V = Self.Value
        switch rawValue {
        case 0: return nil
        case V.currenciesForex:  self = .currencies(.forex)
        case V.indices:          self = .indices
        default: return nil
        }
    }
    
    fileprivate init?(market: IG.API.Market) {
        switch market.instrument.type {
        case .currencies where IG.DB.Market.Forex.isCompatible(market: market): self = .currencies(.forex)
//        case .indices:     self = .indices
//        case .rates:       self = .rates
//        case .options:     self = .options
//        case .shares:      self = .shares
//        case .commodities: self = .commodities
        default: return nil
        }
    }
    
    public var rawValue: Int32 {
        typealias V = Self.Value
        switch self {
        case .currencies(.forex):  return V.currenciesForex
        case .indices:             return V.indices
        }
    }
    
    private enum Value {
        static let currencies:       Int32 = 1
        static let currenciesForex:  Int32 = Self.currencies & (1 << 16)
        static let indices:          Int32 = 2
    }
}

// MARK: Debugging

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

extension IG.DB.Market.Kind {
    public var debugDescription: String {
        switch self {
        case .currencies: return "currencies"
        case .indices: return "indices"
        }
    }
}
