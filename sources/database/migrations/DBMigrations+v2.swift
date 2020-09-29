import Foundation
import SQLite3

extension Database.Migration {
    /// Migration from v1 to v2 where date timestamps are translated from `String`s to integer numbers.
    /// - parameter channel: The SQLite database connection.
    /// - throws: `IG.Error` exclusively.
    internal static func toVersion2(channel: Database.Channel) throws {
        // 1. Retrieve all market epics.
        let epics = try channel.read { (database) -> [String] in
                var statement: SQLite.Statement? = nil
                defer { sqlite3_finalize(statement) }
                try sqlite3_prepare_v2(database, "SELECT epic FROM Markets_Forex;", -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                
                var result: [String] = []
                while true {
                    switch sqlite3_step(statement).result {
                    case .row: result.append(String(cString: sqlite3_column_text(statement!, 0)))
                    case .done: return result
                    case let c: throw IG.Error._queryFailed(code: c)
                    }
                }
            }
        guard !epics.isEmpty else { return try channel.unrestrictedAccess { try $0.set(version: .v2) } }
        
        // 2. Find out all price tables in the database.
        let tableNames = try channel.read { (database) -> [String] in
            var statement: SQLite.Statement? = nil
            defer { sqlite3_finalize(statement) }
            
            let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1"
            try sqlite3_prepare_v2(database, sql, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
            
            var result: [String] = []
            for epic in epics {
                let tableName = "Price_\(epic)"
                sqlite3_bind_text(statement, 1, tableName, -1, SQLite.Destructor.transient)
                
                switch sqlite3_step(statement).result {
                case .row:  result.append(tableName)
                case .done: break
                case let c: throw IG.Error._queryFailed(code: c)
                }
                
                sqlite3_clear_bindings(statement)
                sqlite3_reset(statement)
            }
            
            return result
        }
        guard !tableNames.isEmpty else { return try channel.unrestrictedAccess { try $0.set(version: .v2) } }
        let tmpNames = tableNames.map { $0.appending("_tmp") }
        
        // 3. Rename all price tables.
        try channel.write { (database) -> Void in
            let sql = zip(tableNames, tmpNames).map { "ALTER TABLE '\($0)' RENAME TO '\($1)';" }.joined(separator: " ")
            try sqlite3_exec(database, sql, nil, nil, nil).expects(.ok)
        }
        
        // 4. Create new tables.
        try channel.write { (database) -> Void in
            let sql = tableNames.map { Self.priceTableDefinition(name: $0) }.joined(separator: "\n")
            try sqlite3_exec(database, sql, nil, nil, nil).expects(.ok)
        }
        
        // 5. Iterate through all price tables.
        for (tableName, tmpName) in zip(tableNames, tmpNames) {
            // 5.1. Copy all table data.
            let prices: [Price] = try channel.read { (database) in
                var statement: SQLite.Statement? = nil
                defer { sqlite3_finalize(statement) }
                try sqlite3_prepare_v2(database, "SELECT * FROM '\(tmpName)'", -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                
                var result: [Price] = []
                let formatter = UTC.Timestamp()
                while true {
                    switch sqlite3_step(statement).result {
                    case .row:  result.append(.init(statement: statement!, formatter: formatter))
                    case .done: return result
                    case let c: throw IG.Error._queryFailed(code: c)
                    }
                }
            }
            
            // 5.2. Insert new data.
            try channel.write { (database) in
                var statement: SQLite.Statement? = nil
                defer { sqlite3_finalize(statement) }
                let sql = """
                INSERT INTO '\(tableName)' VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10);
                """
                try sqlite3_prepare_v2(database, sql, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                for p in prices {
                    p.bind(to: statement!)
                    try sqlite3_step(statement).expects(.done) { IG.Error._storingFailed(code: $0) }
                    sqlite3_clear_bindings(statement)
                    sqlite3_reset(statement)
                }
            }
            
            // 5.3. Drop the temporary table.
            try channel.write { (database) in
                try sqlite3_exec(database, "DROP TABLE '\(tmpName)';", nil, nil, nil).expects(.ok) { IG.Error._dropTableFailed(code: $0) }
            }
        }
        
        // 6. Set v2, vacuum, and optimize.
        try channel.unrestrictedAccess { (database) -> Void in
            try database.set(version: .v2)
            try sqlite3_exec(database, "VACUUM", nil, nil, nil).expects(.ok) { IG.Error._vacuumFailed(code: $0) }
            try sqlite3_exec(database, "PRAGMA optimize", nil, nil, nil).expects(.ok) { IG.Error._optimizeFailed(code: $0) }
        }
    }
}

fileprivate extension Database.Migration {
    static func priceTableDefinition(name: String) -> String { """
        CREATE TABLE '\(name)' (
            date     INTEGER NOT NULL,
            openBid  INTEGER NOT NULL, openAsk  INTEGER NOT NULL,
            closeBid INTEGER NOT NULL, closeAsk INTEGER NOT NULL,
            lowBid   INTEGER NOT NULL, lowAsk   INTEGER NOT NULL,
            highBid  INTEGER NOT NULL, highAsk  INTEGER NOT NULL,
            volume   INTEGER NOT NULL,
            
            PRIMARY KEY(date)
        ) WITHOUT ROWID;
        """
    }
    
    struct Price {
        let date: Date
        let (openBid, openAsk): (Int32, Int32)
        let (closeBid, closeAsk): (Int32, Int32)
        let (lowBid, lowAsk): (Int32, Int32)
        let (highBid, highAsk): (Int32, Int32)
        let volume: Int32
        
        init(statement s: SQLite.Statement, formatter: UTC.Timestamp) {
            self.date = formatter.date(from: String(cString: sqlite3_column_text(s, 0)))
            self.openBid = sqlite3_column_int(s, 1)
            self.openAsk = sqlite3_column_int(s, 2)
            self.closeBid = sqlite3_column_int(s, 3)
            self.closeAsk = sqlite3_column_int(s, 4)
            self.lowBid = sqlite3_column_int(s, 5)
            self.lowAsk = sqlite3_column_int(s, 6)
            self.highBid = sqlite3_column_int(s, 7)
            self.highAsk = sqlite3_column_int(s, 8)
            self.volume = sqlite3_column_int(s, 9)
        }
        
        func bind(to statement: SQLite.Statement) {
            sqlite3_bind_int(statement, 1, Int32(self.date.timeIntervalSince1970))
            sqlite3_bind_int(statement, 2, self.openBid)
            sqlite3_bind_int(statement, 3, self.openAsk)
            sqlite3_bind_int(statement, 4, self.closeBid)
            sqlite3_bind_int(statement, 5, self.closeAsk)
            sqlite3_bind_int(statement, 6, self.lowBid)
            sqlite3_bind_int(statement, 7, self.lowAsk)
            sqlite3_bind_int(statement, 8, self.highBid)
            sqlite3_bind_int(statement, 9, self.highAsk)
            sqlite3_bind_int(statement, 10, self.volume)
        }
    }
}

private extension IG.Error {
    /// Error raised when a SQLite command couldn't be compiled.
    static func _compilationFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred trying to compile a SQL statement.", info: ["Error code": code])
    }
    /// Error raised when a SQLite table fails.
    static func _queryFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred querying the SQLite table.", info: ["Table": Database.Price.self, "Error code": code])
    }
    /// Error raised when storing fails.
    static func _storingFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred storing values on '\(Database.Price.self)'.", info: ["Error code": code])
    }
    /// Error raised when a SQLite table cannot be created.
    static func _dropTableFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The drop table statement failed.", info: ["Error code": code])
    }
    /// Error raised when the VACUUM/rebuild command failed to completed.
    static func _vacuumFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The VACUUM statement failed.", help: "Review the error code and contact the repo maintainer.", info: ["Error code": code])
    }
    /// Error raised when the simple optimization call failed.
    static func _optimizeFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The SQLite optimization failed.", help: "Review the error code and contact the repo maintainer.", info: ["Error code": code])
    }
}
