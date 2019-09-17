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
            
            let query = "INSERT INTO \(IG.DB.Market.tableName) VALUES(?1, ?2) ON CONFLICT(epic) DO NOTHING"
            if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
                return .failure(error: .callFailed(.storing(IG.DB.Market.self), code: compileError, suggestion: .reviewError))
            }
            
            for market in markets {
                guard case .continue = requestPermission() else { return .interruption }
                
                let market = IG.DB.Market(epic: market.instrument.epic, type: IG.DB.Market.Kind(market.instrument.type))
                market.bind(to: statement!)
                
                if let updateError = sqlite3_step(statement).enforce(.done) {
                    return .failure(error: .callFailed(.storing(IG.DB.Market.self), code: updateError))
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
//        /// The name of the price table.
//        public let price: String?
    }
}

extension IG.DB.Market {
    /// The type of market (i.e. instrument type).
    public enum Kind: Int32 {
        /// Currencies are medium of exchange.
        case currencies = 0x0001
        /// An index is an statistical measure of change in a securities market.
        case indices = 0x0002
        /// Bonds, money markets, etc.
        case rates = 0x0004
        /// An option is a contract which gives the buyer the right, but not the obligation, to buy or sell an underlying asset or instrument at a specified strike price prior to or on a specified date, depending on the form of the option.
        case options = 0x0008
        /// Commodities are hard assets ranging from wheat to gold to oil.
        case commodities = 0x0010
        /// Shares are unit of ownership interest in a corporation or financial asset that provide for an equal distribution in any profits, if any are declared, in the form of dividends.
        case shares = 0x0020
    }
    
//    /// The type of market (i.e. instrument type).
//    public enum Manolo: RawRepresentable {
//        /// Currencies are medium of exchange.
//        case currencies(Self.Currency)
//        /// An index is an statistical measure of change in a securities market.
//        case indices
//        /// Bonds, money markets, etc.
//        case rates
//        /// An option is a contract which gives the buyer the right, but not the obligation, to buy or sell an underlying asset or instrument at a specified strike price prior to or on a specified date, depending on the form of the option.
//        case options
//        /// Commodities are hard assets ranging from wheat to gold to oil.
//        case commodities
//        /// Shares are unit of ownership interest in a corporation or financial asset that provide for an equal distribution in any profits, if any are declared, in the form of dividends.
//        case shares
//
//        public enum Currency {
//            case forex
//            case crypto
//        }
//
//        public init?(rawValue: Int32) {
//            typealias V = Self.Value
//            switch rawValue {
//            case V.currenciesForex:  self = .currencies(.forex)
//            case V.currenciesCrypto: self = .currencies(.crypto)
//            case V.indices:          self = .indices
//            case V.rates:            self = .rates
//            case V.options:          self = .options
//            case V.commodities:      self = .commodities
//            case V.shares:           self = .shares
//            default: return nil
//            }
//        }
//
//        public var rawValue: Int32 {
//            typealias V = Self.Value
//            switch self {
//            case .currencies(.forex):  return V.currenciesForex
//            case .currencies(.crypto): return V.currenciesCrypto
//            case .indices:             return V.indices
//            case .rates:               return V.rates
//            case .options:             return V.options
//            case .commodities:         return V.commodities
//            case .shares:              return V.shares
//            }
//        }
//
//        private enum Value {
//            static let currencies:       Int32 = 1
//            static let currenciesForex:  Int32 = Self.currencies & (1 << 16)
//            static let currenciesCrypto: Int32 = Self.currencies & (2 << 16)
//            static let indices:          Int32 = 2
//            static let rates:            Int32 = 3
//            static let options:          Int32 = 4
//            static let commodities:      Int32 = 5
//            static let shares:           Int32 = 6
//        }
//    }
}

// MARK: - Functionality

// MARK: SQLite

extension IG.DB.Market: DBTable {
    internal static let tableName: String = "Markets"
    internal static var tableDefinition: String {
        """
        CREATE TABLE \(Self.tableName) (
            epic TEXT    NOT NULL CHECK( LENGTH(epic) BETWEEN 6 AND 30 ),
            type INTEGER,
            
            PRIMARY KEY(epic)
        ) WITHOUT ROWID;
        """
    }
}

fileprivate extension IG.DB.Market {
    typealias Indices = (epic: Int32, type: Int32)
    
    init(statement s: SQLite.Statement, indices: Self.Indices = (0, 1)) {
        self.epic = IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(s, indices.epic)))!
        self.type = Self.Kind(rawValue: sqlite3_column_int(s, indices.type))!
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices = (1, 2)) {
        sqlite3_bind_text(statement, indices.epic, self.epic.rawValue, -1, SQLITE_TRANSIENT)
        switch self.type {
        case let t?: sqlite3_bind_int (statement, indices.type, t.rawValue)
        case .none:  sqlite3_bind_null(statement, indices.type)
        }
    }
}

// MARK: API

fileprivate extension IG.DB.Market.Kind {
    init?(_ type: IG.API.Market.Instrument.Kind) {
        switch type {
        case .currencies:  self = .currencies
        case .indices:     self = .indices
        case .rates:       self = .rates
        case .options:     self = .options
        case .shares:      self = .shares
        case .commodities: self = .commodities
        default: return nil
        }
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
        case .rates: return "rates"
        case .shares: return "shares"
        case .indices: return "indices"
        case .commodities: return "commodities"
        case .currencies: return "currencies"
        case .options: return "options"
        }
    }
}
