import SQLite3

extension IG.DB {
    /// All migrations described in this database.
    internal enum Migration {
        /// Application ID "magic" number used to identify SQLite database files.
        private static let applicationID: Int32 = 840797404
        
        /// The number of versions currently supported
        internal enum Version: Int, Equatable, CaseIterable {
            /// The version for database creation.
            case v0 = 0
            /// The initial version
            case v1 = 1
            
            /// The last described migration.
            static var latest: Self {
                return Self.allCases.last!
            }
        }
        
        /// Apply migrations to the latest version.
        /// - warning: This function will perform a `queue.sync()` operation. Be sure no deadlocks occurs.
        /// - parameter channel: The database connection pointer.
        /// - parameter queue: The priviledge database queue.
        /// - throws: `IG.DB.Error` exclusively.
        internal static func apply(for channel: SQLite.Database, on queue: DispatchQueue) throws {
            // Retrieve the current database version
            let versionNumber = try queue.sync { try Self.version(channel: channel) }
            guard let version = Self.Version(rawValue: versionNumber) else {
                if versionNumber > Self.Version.latest.rawValue {
                    throw IG.DB.Error.invalidResponse(.init(#"The database version number "\#(versionNumber)" is not supported by your current library"#), suggestion: "Update the library to work with the database")
                } else {
                    throw IG.DB.Error.invalidResponse(.init(#"The database version number "\#(versionNumber)" is invalid"#), suggestion: .fileBug)
                }
            }
            // Retrieve the SQLite's file application identifier.
            let applicationID = try queue.sync { try Self.applicationID(channel: channel) }
            guard applicationID == Self.applicationID || (applicationID == 0 && versionNumber == 0) else {
                throw IG.DB.Error.invalidRequest("The SQLite database file is not supported by this application", suggestion: "It seems you are trying to open a SQLite database belonging to another application")
            }
            
            // Select the correct migration
            switch version {
            case .v0: try Self.initialVersion(channel: channel, queue: queue)
            case .v1: return
            }
            // Set the version number to the latest supported version.
            try queue.sync { try Self.setVersion(Self.Version.latest, channel: channel) }
        }
    }
}

extension IG.DB.Migration {
    /// Returns the SQLite's file application ID "magic" number.
    /// - precondition: This should only be called from the database queue.
    /// - parameter channel: The SQLite database connection.
    private static func applicationID(channel: SQLite.Database) throws -> Int32 {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        if let compileError = sqlite3_prepare_v2(channel, "PRAGMA application_id", -1, &statement, nil).enforce(.ok) {
            throw IG.DB.Error.callFailed("The database's user version retrieval statement couldn't be compiled", code: compileError)
        }
        
        if let stepError = sqlite3_step(statement).enforce(.row) {
            throw IG.DB.Error.callFailed("The database's user version couldn't be retrieved", code: stepError)
        }
        
        return sqlite3_column_int(statement, 0)
    }
    
    /// Returns the database version for the given SQLite channel.
    /// - precondition: This should only be called from the database queue.
    /// - parameter channel: The SQLite database connection.
    /// - returns: The number stored on the `PRAGMA user_version` field.
    private static func version(channel: SQLite.Database) throws -> Int {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        if let compileError = sqlite3_prepare_v2(channel, "PRAGMA user_version", -1, &statement, nil).enforce(.ok) {
            throw IG.DB.Error.callFailed("The database's user version retrieval statement couldn't be compiled", code: compileError)
        }
        
        if let stepError = sqlite3_step(statement).enforce(.row) {
            throw IG.DB.Error.callFailed("The database's user version couldn't be retrieved", code: stepError)
        }
        
        return Int(sqlite3_column_int(statement, 0))
    }
    
    /// Sets the SQLite's file application ID "magic" number.
    /// - precondition: This should only be called from the database queue.
    /// - parameter applicationID: The application's magic number (i.e. identifier).
    /// - parameter channel: The SQLite database connection.
    private static func setApplicationID(_ applicationID: Int32, channel: SQLite.Database) throws {
        if let storingError = sqlite3_exec(channel, "PRAGMA application_id = \(applicationID)", nil, nil, nil).enforce(.ok) {
            throw IG.DB.Error.callFailed("The database's user version couldn't be stored", code: storingError)
        }
    }
    
    /// Sets the database user version number.
    /// - precondition: This should only be called from the database queue.
    /// - parameter version: The version number to be set to.
    /// - parameter channel: The SQLite database connection.
    private static func setVersion(_ version: Self.Version, channel: SQLite.Database) throws {
        if let storingError = sqlite3_exec(channel, "PRAGMA user_version = \(version.rawValue)", nil, nil, nil).enforce(.ok) {
            throw IG.DB.Error.callFailed("The database's user version couldn't be stored", code: storingError)
        }
    }
}

extension IG.DB.Migration {
    /// Where the actual migration happens.
    /// - parameter channel: The SQLite database connection.
    private static func initialVersion(channel: SQLite.Database, queue: DispatchQueue) throws {
        queue.sync { _ = sqlite3_exec(channel, "BEGIN TRANSACTION", nil, nil, nil) }
        
        var isRollbackNeeded = false
        defer { queue.sync { _ = sqlite3_exec(channel, String((isRollbackNeeded) ? "ROLLBACK" : "END TRANSACTION"), nil, nil, nil) } }
        
        try queue.sync {
            try Self.setApplicationID(Self.applicationID, channel: channel)
            
            let types: [(DBTable & DebugDescriptable).Type] = [IG.DB.Application.self, IG.DB.Market.self, IG.DB.Market.Forex.self]
            for type in types {
                if let creationError = sqlite3_exec(channel, type.tableDefinition, nil, nil, nil).enforce(.ok) {
                    isRollbackNeeded = true
                    throw IG.DB.Error.callFailed(.init("The SQL statement to create a table for \"\(type.printableDomain)\" failed to execute"), code: creationError)
                }
            }
        }
    }
}
