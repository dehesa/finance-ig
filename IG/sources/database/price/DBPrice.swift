import Combine
import Foundation
import Decimals
import SQLite3

extension Database.Request {
    /// Contains all functionality related to Database user's activity, transaction, and history of prices.
    public struct Price {
        /// Pointer to the actual database instance in charge of the low-level objects.
        fileprivate unowned let _database: Database
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        @usableFromInline internal init(database: Database) { self._database = database }
    }
}

extension Database.Request.Price {
    /// Returns all dates for which there are prices stored in the database.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query. If `nil`, the date at the beginning of the database is assumed.
    /// - parameter to: The date from which to end the query. If `nil`, the date at the end of the database is assumed.
    /// - returns: The dates under which there are prices or an empty array if no data has been previously stored for that timeframe.
    public func getAvailableDates(epic: IG.Market.Epic, from: Date? = nil, to: Date? = nil) -> AnyPublisher<[Date],Database.Error> {
        self._database.publisher { _ -> (tableName: String, query: String) in
            let tableName = Database.Price.tableNamePrefix.appending(epic.rawValue)
            var query = "SELECT date FROM '\(tableName)'"
            switch (from, to) {
            case (let from?, let to?):
                guard from <= to else { throw Database.Error.invalidRequest("The 'from' date must indicate a date before the 'to' date", suggestion: .readDocs) }
                query.append(" WHERE date BETWEEN ?1 AND ?2")
            case (.some, .none): query.append(" WHERE date >= ?1")
            case (.none, .some): query.append(" WHERE date <= ?1")
            case (.none, .none): break
            }
            query.append(" ORDER BY date ASC")
            return (tableName, query)
        }.read { (sqlite, statement, input, _) in
            var result: [Date] = .init()
            // 1. Check the price table is there
            guard try Self._existsPriceTable(epic: epic, sqlite: sqlite) else { return result }
            // 2. Compile the SQL statement
            try sqlite3_prepare_v2(sqlite, input.query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
            // 3. Add the variables to the statement
            switch (from, to) {
            case (let from?, let to?):sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: from), -1, SQLite.Destructor.transient)
                                      sqlite3_bind_text(statement, 2, UTC.Timestamp.string(from: to),   -1, SQLite.Destructor.transient)
            case (let from?, .none):  sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: from), -1, SQLite.Destructor.transient)
            case (.none, let to?):    sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: to),   -1, SQLite.Destructor.transient)
            case (.none, .none):      break
            }
            // 4. Retrieve data
            let formatter = UTC.Timestamp()
            while true {
                switch sqlite3_step(statement).result {
                case .row:
                    let date = formatter.date(from: String(cString: sqlite3_column_text(statement!, 0)))
                    result.append(date)
                case .done: return result
                case let c: throw Database.Error.callFailed(.querying(Database.Price.self), code: c)
                }
            }
            
            return result
        }.mapError(Database.Error.transform)
        .eraseToAnyPublisher()
    }
    
    /// Returns the first available date for which there are prices stored in the database.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - returns: The date furthest in the past stored in the database.
    public func getFirstDate(epic: IG.Market.Epic) -> AnyPublisher<Date?,Database.Error> {
        self._database.publisher { _ -> String in
                let tableName = Database.Price.tableNamePrefix.appending(epic.rawValue)
                return "SELECT MIN(date) FROM '\(tableName)'"
            }.read { (sqlite, statement, query, _) in
                let formatter = UTC.Timestamp()
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                switch sqlite3_step(statement).result {
                case .row:  return formatter.date(from: String(cString: sqlite3_column_text(statement!, 0)))
                case .done: return nil
                case let c: throw Database.Error.callFailed(.querying(Database.Price.self), code: c)
                }
            }.mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }
    
    /// Returns the last available date for which there are prices stored in the database.
    /// - warning: The table existance is not check before using this method.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - returns: The date from "newest" date stored in the database. If `nil`, no price points are for the given table.
    public func getLastDate(epic: IG.Market.Epic) -> AnyPublisher<Date?,Database.Error> {
        self._database.publisher { _ -> String in
                let tableName = Database.Price.tableNamePrefix.appending(epic.rawValue)
                return "SELECT MAX(date) FROM '\(tableName)'"
            }.read { (sqlite, statement, query, _) in
                let formatter = UTC.Timestamp()
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                switch sqlite3_step(statement).result {
                case .row:  return formatter.date(from: String(cString: sqlite3_column_text(statement!, 0)))
                case .done: return nil
                case let c: throw Database.Error.callFailed(.querying(Database.Price.self), code: c)
                }
            }.mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }
    
    /// Returns the number of price points for the given date interval.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query. If `nil`, the date at the beginning of the database is assumed.
    /// - parameter to: The date from which to end the query. If `nil`, the date at the end of the database is assumed.
    public func count(epic: IG.Market.Epic, from: Date? = nil, to: Date? = nil) -> AnyPublisher<Int,Database.Error> {
        self._database.publisher { _ -> String in
                let tableName = Database.Price.tableNamePrefix.appending(epic.rawValue)
                var query = "SELECT COUNT(*) FROM '\(tableName)'"
                switch (from, to) {
                case (let from?, let to?):
                    guard from <= to else { throw Database.Error.invalidRequest("The 'from' date must indicate a date before the 'to' date", suggestion: .readDocs) }
                    query.append(" WHERE date BETWEEN ?1 AND ?2")
                case (.some, .none): query.append(" WHERE date >= ?1")
                case (.none, .some): query.append(" WHERE date <= ?1")
                case (.none, .none): break
                }
                query.append(" ORDER BY date ASC")
                return query
            }.read { (sqlite, statement, query, _) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                // 3. Add the variables to the statement
                switch (from, to) {
                case (let from?, let to?):sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: from), -1, SQLite.Destructor.transient)
                                          sqlite3_bind_text(statement, 2, UTC.Timestamp.string(from: to),   -1, SQLite.Destructor.transient)
                case (let from?, .none):  sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: from), -1, SQLite.Destructor.transient)
                case (.none, let to?):    sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: to),   -1, SQLite.Destructor.transient)
                case (.none, .none):      break
                }
                switch sqlite3_step(statement).result {
                case .row:  return Int(sqlite3_column_int(statement!, 0))
                case .done: fatalError()
                case let c: throw Database.Error.callFailed(.querying(Database.Price.self), code: c)
                }
            }.mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }
}

extension Database.Request.Price {
    /// Returns historical prices for a particular instrument.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query. If `nil`, the retrieved data starts with the first ever recorded price.
    /// - parameter to: The date from which to end the query. If `nil`, the retrieved data ends with the last recorded price.
    /// - returns: The requested price points or an empty array if no data has been previously stored for that timeframe.
    public func get(epic: IG.Market.Epic, from: Date? = nil, to: Date? = nil) -> AnyPublisher<[Database.Price],Database.Error> {
        self._database.publisher { _ -> (tableName: String, query: String) in
            let tableName = Database.Price.tableNamePrefix.appending(epic.rawValue)
            var query = "SELECT * FROM '\(tableName)'"
            switch (from, to) {
            case (let from?, let to?):
                guard from <= to else { throw Database.Error.invalidRequest("The 'from' date must indicate a date before the 'to' date", suggestion: .readDocs) }
                query.append(" WHERE date BETWEEN ?1 AND ?2")
            case (.some, .none): query.append(" WHERE date >= ?1")
            case (.none, .some): query.append(" WHERE date <= ?1")
            case (.none, .none): break
            }
            query.append(" ORDER BY date ASC")
            return (tableName, query)
        }.read { (sqlite, statement, input, _) in
            var result: [Database.Price] = .init()
            // 1. Check the price table is there.
            guard try Self._existsPriceTable(epic: epic, sqlite: sqlite) else { return result }
            // 2. Compile the SQL statement
            try sqlite3_prepare_v2(sqlite, input.query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
            // 3. Add the variables to the statement
            switch (from, to) {
            case (let from?, let to?):sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: from), -1, SQLite.Destructor.transient)
                                      sqlite3_bind_text(statement, 2, UTC.Timestamp.string(from: to),   -1, SQLite.Destructor.transient)
            case (let from?, .none):  sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: from), -1, SQLite.Destructor.transient)
            case (.none, let to?):    sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: to),   -1, SQLite.Destructor.transient)
            case (.none, .none):      break
            }
            
            let formatter = UTC.Timestamp()
            while true {
                switch sqlite3_step(statement).result {
                case .row:  result.append(.init(statement: statement!, formatter: formatter))
                case .done: return result
                case let c: throw Database.Error.callFailed(.querying(Database.Price.self), code: c)
                }
            }
            
            return result
        }.mapError(Database.Error.transform)
        .eraseToAnyPublisher()
    }
    
    /// Returns the first price starting from a given date to an optional end date (or the last stored price) which matches the buying or selling price.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query. If `nil`, all prices from `from` to the end available prices will be searched.
    /// - parameter buying: The buying price at which to match the price.
    /// - parameter selling: The selling price at which to match the price.
    /// - returns: A signal with price point matching the closure as value.
    public func first(epic: IG.Market.Epic, from: Date, to: Date?, buying: Decimal64, selling: Decimal64) -> AnyPublisher<Database.Price?,Database.Error> {
        return self._database.publisher { _ -> (tableName: String, query: String) in
            let tableName = Database.Price.tableNamePrefix.appending(epic.rawValue)
            var query = "SELECT * FROM '\(tableName)'"
            
            if let to = to {
                guard from <= to else {
                    throw Database.Error.invalidRequest("The 'from' date must indicate a date before the 'to' date", suggestion: .readDocs)
                }
                query.append(" WHERE date BETWEEN ?1 AND ?2")
            } else {
                query.append(" WHERE date > ?1")
            }
            
            let buyPrice = Int32(clamping: buying << Database.Price.Point.powerOf10)
            query.append(" AND (\(buyPrice) <= highBid")
            let sellPrice = Int32(clamping: selling << Database.Price.Point.powerOf10)
            query.append(" OR \(sellPrice) >= lowAsk)")
            
            query.append(" ORDER BY date ASC LIMIT 1")
            return (tableName, query)
        }.write { (sqlite, statement, input, _) in
            // 1. Compile the SQL statement (there is no check for price table).
            try sqlite3_prepare_v2(sqlite, input.query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
            // 3. Add the variables to the statement
            sqlite3_bind_text(statement, 1, UTC.Timestamp.string(from: from), -1, SQLite.Destructor.transient)
            if let to = to {
                sqlite3_bind_text(statement, 2, UTC.Timestamp.string(from: to), -1, SQLite.Destructor.transient)
            }
            
            let formatter = UTC.Timestamp()
            // 4. Retrieve data
            switch sqlite3_step(statement).result {
            case .row:  return .init(statement: statement!, formatter: formatter)
            case .done: return nil
            case let c: throw Database.Error.callFailed(.querying(Database.Price.self), code: c)
            }
        }.mapError(Database.Error.transform)
        .eraseToAnyPublisher()
    }
}

extension Database.Request.Price {
    /// Updates the database with the information received from the server.
    /// - note: The market must be in the database before storing its price points.
    /// - parameter prices: The array of price points that have arrived from the server.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - returns: A publisher that completes successfully (without sending any value) if the operation has been successful.
    public func update(_ prices: [API.Price], epic: IG.Market.Epic) -> AnyPublisher<Never,Database.Error> {
        self._database.publisher { _ in
                Self._priceInsertionQuery(epic: epic)
            }.write { (sqlite, statement, input, _) -> Void in
                // 1. Check the epic is on the Markets table.
                guard try Self._existsMarket(epic: epic, sqlite: sqlite) else {
                    throw Database.Error.invalidRequest(.init("The market with epic '\(epic)' must be in the database before storing its price points"), suggestion: .init("Store explicitly the market and the call this function again."))
                }
                // 2. Check the existance of the price table or create it if it is not there.
                if try !Self._existsPriceTable(epic: epic, sqlite: sqlite) {
                    try sqlite3_exec(sqlite, Database.Price.tableDefinition(name: input.tableName), nil, nil, nil).expects(.ok) {
                        .callFailed(.init("The SQL statement to create a table for '\(input.tableName)' failed to execute"), code: $0)
                    }
                }
                // 3. Add the data to the database.
                try sqlite3_prepare_v2(sqlite, input.query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
                for p in prices {
                    guard let v = p.volume else {
                        throw Database.Error.invalidRequest(.init("There must be volume for the price point to be stored in the database"), suggestion: .fileBug)
                    }
                    let price = Database.Price(date: p.date,
                                            open: .init(bid: p.open.bid, ask: p.open.ask),
                                            close: .init(bid: p.close.bid, ask: p.close.ask),
                                            lowest: .init(bid: p.lowest.bid, ask: p.lowest.ask),
                                            highest: .init(bid: p.highest.bid, ask: p.highest.ask),
                                            volume: .init(clamping: v))
                    price._bind(to: statement!)
                    try sqlite3_step(statement).expects(.done) { .callFailed(.storing(Database.Price.self), code: $0) }
                    sqlite3_clear_bindings(statement)
                    sqlite3_reset(statement)
                }
            }.ignoreOutput()
            .mapError(Database.Error.transform)
            .eraseToAnyPublisher()
    }
}

extension Publisher where Output==Streamer.Chart.Aggregated {
    /// Updates the database with the price values provided on the stream.
    ///
    /// The returned publisher forwards any previous error or generates `Database.Error` on some specific scenarios. If upstream there were no errors you can safely forcecast the error to the database error.
    /// - warning: This operator doesn't check the market is currently stored in the database. Please check the market basic information is stored and there is a price table for the epic before calling this operator.
    /// - parameter database: Database where the price data will be stored.
    /// - parameter ignoringInvalidPrices: Boolean indicating whether invalid price data received should be ignored or throw an error (an break the pipeline. Even with this argument is set to `true`, the publisher may generate errors, such as when the database pointer disappears or there is a writting error.
    public func updatePrice(database: Database, ignoringInvalidPrices: Bool) -> AnyPublisher<Database.PriceWrapper,Swift.Error> {
        self.tryCompactMap { [weak database] (price) -> Database.Transit.Instance<(query: String, data: Database.PriceWrapper)>? in
            guard let db = database else { throw Database.Error.sessionExpired() }
            guard let date = price.candle.date,
                  let openBid = price.candle.open.bid,
                  let openAsk = price.candle.open.ask,
                  let closeBid = price.candle.close.bid,
                  let closeAsk = price.candle.close.ask,
                  let lowestBid = price.candle.lowest.bid,
                  let lowestAsk = price.candle.lowest.ask,
                  let highestBid = price.candle.highest.bid,
                  let highestAsk = price.candle.highest.ask,
                  let volume = price.candle.numTicks else {
                guard !ignoringInvalidPrices else { return nil }
                throw Database.Error.invalidRequest("The emitted price value is missing some properties", suggestion: "Retry the connection")
            }
            
            let query = Database.Request.Price._priceInsertionQuery(epic: price.epic).query
            let streamPrice = Database.PriceWrapper(
                    epic: price.epic, interval: price.interval,
                    price: .init(date: date, open: .init(bid: openBid, ask: openAsk),
                                close: .init(bid: closeBid, ask: closeAsk),
                                lowest: .init(bid: lowestBid, ask: lowestAsk),
                                highest: .init(bid: highestBid, ask: highestAsk), volume: volume))
            return ( db, (query, streamPrice) )
        }.write { (sqlite, statement, input, _) -> Database.PriceWrapper in
            try sqlite3_prepare_v2(sqlite, input.query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
            input.data.price._bind(to: statement!)
            try sqlite3_step(statement).expects(.done) { .callFailed(.storing(Database.Price.self), code: $0) }
            sqlite3_clear_bindings(statement)
            sqlite3_reset(statement)
            return input.data
        }.eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension Database {
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
    
    /// Price proceeding from a `Streamer` session that has been processed by the database.
    public struct PriceWrapper {
        /// The identifier for the sourcing market.
        public let epic: IG.Market.Epic
        /// The price resolution (e.g. one second, five minutes, etc.).
        public let interval: Streamer.Chart.Aggregated.Interval
        /// The actual price.
        public let price: Database.Price
    }
}

extension Database.Price {
    /// Price Snap.
    public struct Point: Decodable {
        /// Bid price (i.e. the price another trader is willing to buy for).
        ///
        /// The _bid price_ is always lower than the _ask price_.
        public let bid: Decimal64
        /// Ask price (i.e. the price another trader will sell at).
        ///
        /// The _ask price_ is always higher than the _bid price_.
        public let ask: Decimal64
        /// The middle price between the *bid* and the *ask* price.
        @_transparent public var mid: Decimal64 { self.bid + Decimal64(5, power: -1)! * (self.ask - self.bid) }
    }
}

// MARK: - Functionality

// MARK: SQLite

extension Database.Price {
    internal static let tableNamePrefix: String = "Price_"
    internal static func tableDefinition(name: String) -> String { """
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

fileprivate extension Database.Price {
    typealias _Indices = (date: Int32, openBid: Int32, openAsk: Int32, closeBid: Int32, closeAsk: Int32, lowBid: Int32, lowAsk: Int32, highBid: Int32, highAsk: Int32, volume: Int32)
    
    init(statement s: SQLite.Statement, formatter: UTC.Timestamp, indices: _Indices = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)) {
        self.date = formatter.date(from: String(cString: sqlite3_column_text(s, indices.date)))
        self.open = .init(statement: s, indices: (indices.openBid, indices.openAsk))
        self.close = .init(statement: s, indices: (indices.closeBid, indices.closeAsk))
        self.lowest = .init(statement: s, indices: (indices.lowBid, indices.lowAsk))
        self.highest = .init(statement: s, indices: (indices.highBid, indices.highAsk))
        self.volume = Int(sqlite3_column_int(s, indices.volume))
    }
    
    func _bind(to statement: SQLite.Statement, indices: _Indices = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)) {
        sqlite3_bind_text(statement, indices.date, UTC.Timestamp.string(from: self.date), -1, SQLite.Destructor.transient)
        self.open.bind(to: statement, indices: (indices.openBid, indices.openAsk))
        self.close.bind(to: statement, indices: (indices.closeBid, indices.closeAsk))
        self.lowest.bind(to: statement, indices: (indices.lowBid, indices.lowAsk))
        self.highest.bind(to: statement, indices: (indices.highBid, indices.highAsk))
        sqlite3_bind_int(statement, indices.volume, Int32(self.volume))
    }
}

fileprivate extension Database.Price.Point {
    typealias _Indices = (bid: Int32, ask: Int32)
    static let powerOf10: Int = 5
    
    init(statement s: SQLite.Statement, indices: _Indices) {
        self.bid = Decimal64(.init(sqlite3_column_int(s, indices.bid)), power: -Self.powerOf10)!
        self.ask = Decimal64(.init(sqlite3_column_int(s, indices.ask)), power: -Self.powerOf10)!
    }
    
    func bind(to statement: SQLite.Statement, indices: _Indices) {
        sqlite3_bind_int(statement, indices.bid, .init(clamping: self.bid << Self.powerOf10))
        sqlite3_bind_int(statement, indices.ask, .init(clamping: self.ask << Self.powerOf10))
    }
}

// MARK: Requests

extension Database.Request.Price {
    /// SQLite query to insert a `Database.Price` in the database.
    /// - parameter epic: The market epic being targeted.
    fileprivate static func _priceInsertionQuery(epic: IG.Market.Epic) -> (tableName: String, query: String) {
        let tableName = Database.Price.tableNamePrefix.appending(epic.rawValue)
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
    }
    
    /// Returns a Boolean indicating whether the market is currently stored in the database.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter sqlite: SQLite pointer priviledge access.
    private static func _existsMarket(epic: IG.Market.Epic, sqlite: SQLite.Database) throws -> Bool {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        let query = "SELECT 1 FROM \(Database.Market.tableName) WHERE epic=?1"
        try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
        try sqlite3_bind_text(statement, 1, epic.rawValue, -1, SQLite.Destructor.transient).expects(.ok) { .callFailed(.bindingAttributes, code: $0) }
        
        switch sqlite3_step(statement).result {
        case .row:  return true
        case .done: return false
        case let c: throw Database.Error.callFailed(.init("SQLite couldn't verify the existance of the market with epic '\(epic)'"), code: c)
        }
    }
    
    /// Returns a Boolean indicating whether the price table exists in the database.
    /// - parameter epic: Instrument's epic (such as `CS.D.EURUSD.MINI.IP`).
    /// - parameter sqlite: SQLite pointer priviledge access.
    fileprivate static func _existsPriceTable(epic: IG.Market.Epic, sqlite: SQLite.Database) throws -> Bool {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        let query = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1"
        try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { .callFailed(.compilingSQL, code: $0) }
        
        let tableName = Database.Price.tableNamePrefix.appending(epic.rawValue)
        sqlite3_bind_text(statement, 1, tableName, -1, SQLite.Destructor.transient)
        
        switch sqlite3_step(statement).result {
        case .row:  return true
        case .done: return false
        case let c: throw Database.Error.callFailed(.init("SQLite couldn't verify the existance of the '\(epic)''s price table"), code: c)
        }
    }
}
