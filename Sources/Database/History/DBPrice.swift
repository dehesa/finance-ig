import ReactiveSwift
import Foundation
import SQLite3

extension IG.DB.Request {
    /// Contains all functionality related to DB user's activity, transaction, and history of prices.
    public struct History {
        /// Pointer to the actual database instance in charge of the low-level objects.
        fileprivate unowned let database: IG.DB
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        internal init(database: IG.DB) { self.database = database }
    }
}

extension IG.DB.Request.History {
    /// Returns historical prices for a particular instrument.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    public func getPrices(epic: IG.Market.Epic, from: Date, to: Date = Date()) -> SignalProducer<[IG.DB.Price],IG.DB.Error> {
        return self.database.work { (channel, requestPermission) in
            sqlite3_exec(channel, "BEGIN TRANSACTION", nil, nil, nil)
            defer { sqlite3_exec(channel, "END TRANSACTION", nil, nil, nil) }
            
            var statement: SQLite.Statement? = nil
            defer { sqlite3_finalize(statement) }
            // 1. Check that the price table is there.
            let existanceQuery = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1"
            if let compileError = sqlite3_prepare_v2(channel, existanceQuery, -1, &statement, nil).enforce(.ok) {
                return .failure(.callFailed(.compilingSQL, code: compileError))
            }
            
            let tableName = IG.DB.Price.tableNamePrefix.appending(epic.rawValue)
            sqlite3_bind_text(statement, 1, tableName, -1, SQLite.Destructor.transient)
            
            var result: [IG.DB.Price] = .init()
            switch sqlite3_step(statement).result {
            case .row: sqlite3_finalize(statement)
            case .done: return .success(result)
            case let c: return .failure(.callFailed(.init("SQLite couldn't verify the existance of the \"\(epic)\"'s price table"), code: c))
            }
            
            // 2. Retrieve any day from the table.
            let retrievalQuery = "SELECT * FROM ?1 WHERE date BETWEEN ?2 AND ?3"
            if let compileError = sqlite3_prepare_v2(channel, retrievalQuery, -1, &statement, nil).enforce(.ok) {
                return .failure(.callFailed(.compilingSQL, code: compileError))
            }
            
            let formatter = IG.DB.Formatter.timestamp
            sqlite3_bind_text(statement, 1, tableName, -1, SQLite.Destructor.transient)
            sqlite3_bind_text(statement, 2, formatter.string(from: from), -1, SQLite.Destructor.transient)
            sqlite3_bind_text(statement, 3, formatter.string(from: to), -1, SQLite.Destructor.transient)
            
            repeat {
                switch sqlite3_step(statement).result {
                case .row:  result.append(.init(statement: statement!))
                case .done: return .success(result)
                case let c: return .failure(.callFailed(.querying(IG.DB.Price.self), code: c))
                }
            } while requestPermission().isAllowed
            
            return .interruption
        }
    }
    
//    /// Updates the database with the information received from the server.
//    public func udpate(prices: [IG.API.Price], epic: IG.Market.Epic) -> SignalProducer<Void,IG.DB.Error> {
//
//    }
//
//    private func update(prices: [IG.DB.Price], epic: IG.Market.Epic) -> SignalProducer<Void,IG.DB.Error> {
//
//    }
}

// MARK: - Entities

extension IG.DB {
    /// Historical market price snapshot.
    public struct Price {
        /// Snapshot date.
        public let date: Date
        /// Open session price.
        public let open: Self.Point
        /// Close session price.
        public let close: Self.Point
        /// Lowest price.
        public let lowest: Self.Point
        /// Highest price.
        public let highest: Self.Point
        /// Last traded volume.
        public let volume: Int
    }
}

extension IG.DB.Price {
    /// Price Snap.
    public struct Point: Decodable {
        /// Bid price (i.e. the price being offered  to buy an asset).
        public let bid: Decimal
        /// Ask price (i.e. the price being asked to sell an asset).
        public let ask: Decimal
        
        /// The middle price between the *bid* and the *ask* price.
        public var mid: Decimal {
            return self.bid + 0.5 * (self.ask - self.bid)
        }
    }
}

// MARK: - Functionality

// MARK: SQLite

extension IG.DB.Price {
    internal static let tableNamePrefix: String = "Price_"
    internal static func tableDefinition(name: String) -> String { return """
        CREATE TABLE \(name) (
            date     TEXT    NOT NULL CHECK( (date IS DATETIME(date)) AND (date <= CURRENT_TIMESTAMP) ),
            openBid  INTEGER NOT NULL,
            openAsk  INTEGER NOT NULL,
            closeBid INTEGER NOT NULL,
            closeAsk INTEGER NOT NULL,
            lowBid   INTEGER NOT NULL,
            lowAsk   INTEGER NOT NULL,
            highBid  INTEGER NOT NULL,
            highAsk  INTEGER NOT NULL,
            volume   INTEGER NOT NULL,
        
            PRIMARY KEY(date)
        ) WITHOUT ROWID;
        """
    }
}

fileprivate extension IG.DB.Price {
    typealias Indices = (date: Int32, openBid: Int32, openAsk: Int32, closeBid: Int32, closeAsk: Int32, lowBid: Int32, lowAsk: Int32, highBid: Int32, highAsk: Int32, volume: Int32)
    
    init(statement s: SQLite.Statement, indices: Self.Indices = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)) {
        self.date = IG.DB.Formatter.timestamp.date(from: String(cString: sqlite3_column_text(s, indices.date)))!
        self.open = .init(statement: s, indices: (indices.openBid, indices.openAsk))
        self.close = .init(statement: s, indices: (indices.closeBid, indices.closeAsk))
        self.lowest = .init(statement: s, indices: (indices.lowBid, indices.lowAsk))
        self.highest = .init(statement: s, indices: (indices.highBid, indices.highAsk))
        self.volume = Int(sqlite3_column_int(s, indices.volume))
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)) {
        sqlite3_bind_text(statement, indices.date, IG.DB.Formatter.timestamp.string(from: self.date), -1, SQLite.Destructor.transient)
        self.open.bind(to: statement, indices: (indices.openBid, indices.openAsk))
        self.close.bind(to: statement, indices: (indices.closeBid, indices.closeAsk))
        self.lowest.bind(to: statement, indices: (indices.lowBid, indices.lowAsk))
        self.highest.bind(to: statement, indices: (indices.highBid, indices.highAsk))
        sqlite3_bind_int(statement, indices.volume, Int32(self.volume))
    }
}

fileprivate extension IG.DB.Price.Point {
    typealias Indices = (bid: Int32, ask: Int32)
    
    init(statement s: SQLite.Statement, indices: Self.Indices) {
        self.bid = Decimal(sqlite3_column_int(s, indices.bid), divingByPowerOf10: 5)
        self.ask = Decimal(sqlite3_column_int(s, indices.ask), divingByPowerOf10: 5)
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices) {
        sqlite3_bind_int(statement, indices.bid, .init(clamping: self.bid, multiplyingByPowerOf10: 5))
        sqlite3_bind_int(statement, indices.ask, .init(clamping: self.ask, multiplyingByPowerOf10: 5))
    }
}

// MARK: Debuggin

extension IG.DB.Price: IG.DebugDescriptable {
    static var printableDomain: String {
        return IG.DB.printableDomain.appending(".\(Self.self)")
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("date", self.date, formatter: IG.Formatter.timestamp.deepCopy.set { $0.timeZone = .current })
        result.append("open/close", "\(self.open.mid) -> \(self.close.mid)")
        result.append("lowest/highest", "\(self.lowest.mid) -> \(self.highest.mid)")
        result.append("volume", self.volume)
        return result.generate()
    }
}
