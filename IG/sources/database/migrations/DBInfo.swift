import SQLite3

internal extension Database {
    /// Returns the SQLite user identifier and user version for the receiving database.
    /// - throws: `IG.Error` exclusively.
    final func info() throws -> (applicationID: Int32, version: Database.Version) {
        // Retrieve the current database version
        let versionId = try self.channel.unrestrictedAccess { try $0.version() }
        guard let version = Database.Version(rawValue: versionId) else {
            if versionId > Database.Version.latest.rawValue {
                throw IG.Error._unsupported(version: versionId)
            } else {
                throw IG.Error._invalid(version: versionId)
            }
        }
        
        // Retrieve the SQLite's file application identifier.
        let appId = try self.channel.unrestrictedAccess { try $0.applicationId() }
        guard appId == Database.applicationId || (appId == 0 && versionId == 0) else {
            throw IG.Error._invalid(applicationId: appId)
        }
        
        return (appId, version)
    }
}

internal extension SQLite.Database {
    /// Returns the SQLite's file application ID "magic" number.
    /// - precondition: This should only be called from the database queue.
    func applicationId() throws -> Int32 {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        try sqlite3_prepare_v2(self, "PRAGMA application_id", -1, &statement, nil).expects(.ok) { IG.Error._invalidApplicationRetrieval(code: $0) }
        try sqlite3_step(statement).expects(.row) { IG.Error._applicationRetrievalFailed(code: $0) }
        return sqlite3_column_int(statement, 0)
    }
    
    /// Sets the SQLite's file application ID "magic" number.
    /// - precondition: This should only be called from the database queue.
    /// - parameter applicationId: The application's magic number (i.e. identifier).
    func set(applicationId: Int32) throws {
        try sqlite3_exec(self, "PRAGMA application_id = \(applicationId)", nil, nil, nil).expects(.ok) {
            IG.Error._applicationStorageFailed(code: $0)
        }
    }
    
    /// Returns the database version for the given SQLite channel.
    /// - precondition: This should only be called from the database queue.
    /// - returns: The number stored on the `PRAGMA user_version` field.
    func version() throws -> Int {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        try sqlite3_prepare_v2(self, "PRAGMA user_version", -1, &statement, nil).expects(.ok) { IG.Error._invalidUserVersionRetrieval(code: $0) }
        try sqlite3_step(statement).expects(.row) { IG.Error._userVersionRetrievalFailed(code: $0) }
        return Int(sqlite3_column_int(statement, 0))
    }
    
    /// Sets the database user version number.
    /// - precondition: This should only be called from the database queue.
    /// - parameter version: The version number to be set to.
    func set(version: Database.Version) throws {
        try sqlite3_exec(self, "PRAGMA user_version = \(version.rawValue)", nil, nil, nil).expects(.ok) {
            IG.Error._userVersionStorageFailed(code: $0)
        }
    }
}

private extension IG.Error {
    /// Error raised when the database version is not supported.
    static func _unsupported(version: Int) -> Self {
        Self(.database(.invalidResponse), "The database version number is not supported by your current library.", help: "Update the library to work with the database.", info: ["Version": version])
    }
    /// Error raised when an invalid version number is received.
    static func _invalid(version: Int) -> Self {
        Self(.database(.invalidResponse), "The database version number is invalid.", help: "A unexpected error was encountered. Please contact the repository maintainer and attach this debug print.", info: ["Version": version])
    }
    /// Error raised when an invalid SQLite application identifier is received.
    static func _invalid(applicationId: Int32) -> Self {
        Self(.database(.invalidRequest), "The SQLite database file is not supported by this application.", help: "It seems you are trying to open a SQLite database belonging to another application")
    }
    /// Error raised when the SQLite application identifier command couldn't be compiled.
    static func _invalidApplicationRetrieval(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The database's user version retrieval statement couldn't be compiled.", info: ["Error code": code])
    }
    /// Error raised when the SQLite application retrieval failed.
    static func _applicationRetrievalFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The database's user version couldn't be retrieved.", info: ["Error code": code])
    }
    /// Error raised when the SQLite user version command couldn't be compiled.
    static func _invalidUserVersionRetrieval(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The database's user version retrieval statement couldn't be compiled.", info: ["Error code": code])
    }
    /// Error raised when the SQLite user version retrieval failed.
    static func _userVersionRetrievalFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The database's user version couldn't be retrieved.", info: ["Error code": code])
    }
    /// Error raised when the SQLite user version storage couldn't be compiled.
    static func _applicationStorageFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The database's application couldn't be stored.", info: ["Error code": code])
    }
    /// Error raised when the SQLite user version storage failed.
    static func _userVersionStorageFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The database's user version couldn't be stored.", info: ["Error code": code])
    }
}
