import Combine
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
    /// - returns: The requested price points or an empty array if no data has been previously stored for that timeframe.
    public func getPrices(epic: IG.Market.Epic, from: Date, to: Date = Date()) -> IG.DB.DiscretePublisher<[IG.DB.Price]> {
        self.database.publisher { _ -> (tableName: String, query: String) in
            let tableName = IG.DB.Price.tableNamePrefix.appending(epic.rawValue)
            let query = ("SELECT * FROM '\(tableName)' WHERE date BETWEEN ?1 AND ?2")
            return (tableName, query)
        }.read { (sqlite, statement, input) in
            var result: [IG.DB.Price] = .init()
            
            // 1. Check the price table is there.
            guard try Self.existsPriceTable(epic: epic, sqlite: sqlite) else { return result }
            
            // 2. Retrieve the requested data
            try sqlite3_prepare_v2(sqlite, input.query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
            
            let formatter = IG.DB.Formatter.timestamp
            sqlite3_bind_text(statement, 1, formatter.string(from: from), -1, SQLite.Destructor.transient)
            sqlite3_bind_text(statement, 2, formatter.string(from: to), -1, SQLite.Destructor.transient)
            while true {
                switch sqlite3_step(statement).result {
                case .row:  result.append(.init(statement: statement!))
                case .done: return result
                case let c: throw IG.DB.Error.callFailed(.querying(IG.DB.Price.self), code: c)
                }
            }
            
            return result
        }.eraseToAnyPublisher()
    }

    /// Updates the database with the information received from the server.
    /// - note: The market must be in the database before storing its price points.
    /// - parameter prices: The array of price points that have arrived from the server.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - returns: A publisher that completes successfully (without sending any value) if the operation has been successful.
    public func update(prices: [IG.API.Price], epic: IG.Market.Epic) -> IG.DB.DiscretePublisher<Never> {
        self.database.publisher { _ -> (tableName: String, query: String) in
            let tableName = IG.DB.Price.tableNamePrefix.appending(epic.rawValue)
            let query = """
                INSERT INTO '\(tableName)' VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
                    ON CONFLICT(date) DO UPDATE SET
                    openBid=excluded.openBid, openAsk=excluded.openAsk,
                    closeBid=excluded.closeBid, closeAsk=excluded.closeAsk,
                    lowBid=excluded.lowBid, lowAsk=excluded.lowAsk,
                    highBid=excluded.highBid, highAsk=excluded.highAsk,
                    volume=excluded.volume
                """
            return (tableName, query)
        }.write { (sqlite, statement, input) -> Void in
            // 1. Check the epic is on the Markets table.
            guard try Self.existsMarket(epic: epic, sqlite: sqlite) else {
                throw IG.DB.Error.invalidRequest(.init(#"The market with epic "\#(epic)" must be in the database before storing its price points"#), suggestion: .init("Store explicitly the market and the call this function again."))
            }
            // 2. Check the existance of the price table or create it if it is not there.
            if try !Self.existsPriceTable(epic: epic, sqlite: sqlite) {
                try sqlite3_exec(sqlite, IG.DB.Price.tableDefinition(name: input.tableName), nil, nil, nil).expects(.ok) {
                    .callFailed(.init(#"The SQL statement to create a table for "\#(input.tableName)" failed to execute"#), code: $0)
                }
            }
            // 3. Add the data to the database.
            try sqlite3_prepare_v2(sqlite, input.query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
            for p in prices {
                guard let v = p.volume else {
                    throw IG.DB.Error.invalidRequest(.init("There must be volume for the price point to be stored in the database"), suggestion: .fileBug)
                }
                let price = IG.DB.Price(date: p.date,
                                        open: .init(bid: p.open.bid, ask: p.open.ask),
                                        close: .init(bid: p.close.bid, ask: p.close.ask),
                                        lowest: .init(bid: p.lowest.bid, ask: p.lowest.ask),
                                        highest: .init(bid: p.highest.bid, ask: p.highest.ask),
                                        volume: .init(clamping: v))
                price.bind(to: statement!)
                try sqlite3_step(statement).expects(.done) { .callFailed(.storing(IG.DB.Application.self), code: $0) }
                sqlite3_clear_bindings(statement)
                sqlite3_reset(statement)
            }
        }.ignoreOutput()
        .eraseToAnyPublisher()
    }
}

extension IG.DB.Request.History {
    /// Returns a Boolean indicating whether the market is currently stored in the database.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter sqlite: SQLite pointer priviledge access.
    private static func existsMarket(epic: IG.Market.Epic, sqlite: SQLite.Database) throws -> Bool {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        let query = "SELECT 1 FROM \(IG.DB.Market.tableName) WHERE epic=?1"
        try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
        try sqlite3_bind_text(statement, 1, epic.rawValue, -1, SQLite.Destructor.transient).expects(.ok) { .callFailed(.bindingAttributes, code: $0) }
        
        switch sqlite3_step(statement).result {
        case .row:  return true
        case .done: return false
        case let c: throw IG.DB.Error.callFailed(.init("SQLite couldn't verify the existance of the market with epic \"\(epic)\""), code: c)
        }
    }
    
    /// Returns a Boolean indicating whether the price table exists in the database.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter sqlite: SQLite pointer priviledge access.
    private static func existsPriceTable(epic: IG.Market.Epic, sqlite: SQLite.Database) throws -> Bool {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        let query = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1"
        try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
        
        let tableName = IG.DB.Price.tableNamePrefix.appending(epic.rawValue)
        sqlite3_bind_text(statement, 1, tableName, -1, SQLite.Destructor.transient)
        
        switch sqlite3_step(statement).result {
        case .row:  return true
        case .done: return false
        case let c: throw IG.DB.Error.callFailed(.init("SQLite couldn't verify the existance of the \"\(epic)\"'s price table"), code: c)
        }
    }
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
        CREATE TABLE '\(name)' (
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

// MARK: Debugging

extension IG.DB.Price: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return IG.DB.printableDomain.appending(".\(Self.self)")
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("date", self.date, formatter: IG.DB.Formatter.timestamp.deepCopy(timeZone: .current))
        result.append("open/close", "\(self.open.mid) -> \(self.close.mid)")
        result.append("lowest/highest", "\(self.lowest.mid) -> \(self.highest.mid)")
        result.append("volume", self.volume)
        return result.generate()
    }
}