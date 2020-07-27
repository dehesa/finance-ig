import Foundation
import SQLite3

extension Database {
    /// Migrates the hosted database from its version to a targeted version.
    /// - parameter toVersion: The desired database version.
    /// - throws: `IG.Error` exclusively if the database is already on a higher version number or there were problems during migration.
    internal final func migrate(to toVersion: Database.Migration.Version) throws {
        var info = try self._migrationInfo()
        guard info.version != toVersion else { return }
        guard info.version < toVersion else { throw IG.Error._unsupported(version: info.version.rawValue) }
        
        repeat {
            let nextVersion = info.version.next!
            try self._migrateToNextVersion()
            info.version = nextVersion
        } while info.version != toVersion
    }
    
    /// Apply the needed migrations to reach the hosted database to the latest version.
    /// - throws: `IG.Error` exclusively.
    internal final func migrateToLatestVersion() throws {
        var info = try self._migrationInfo()
        
        while let nextVersion = info.version.next {
            try self._migrateToNextVersion()
            info.version = nextVersion
        }
    }
    
    /// - precondition: The database version number is expected to be valid at this moment.
    /// - throws: `IG.Error` exclusively.
    private final func _migrateToNextVersion() throws {
        typealias M = Database.Migration
        switch M.Version(rawValue: try self.channel.unrestrictedAccess(M.version))! {
        case .v0: try M.initialMigration(channel: self.channel)
        case .v1: break
        }
    }
    
    /// - throws: `IG.Error` exclusively.
    private final func _migrationInfo() throws -> (applicationID: Int32, version: Database.Migration.Version) {
        // Retrieve the current database version
        let versionNumber = try self.channel.unrestrictedAccess(Database.Migration.version)
        guard let version = Database.Migration.Version(rawValue: versionNumber) else {
            if versionNumber > Database.Migration.Version.latest.rawValue {
                throw IG.Error._unsupported(version: versionNumber)
            } else {
                throw IG.Error._invalid(version: versionNumber)
            }
        }
        
        // Retrieve the SQLite's file application identifier.
        let applicationID = try self.channel.unrestrictedAccess(Database.Migration.applicationID)
        guard applicationID == Database.Migration.applicationID || (applicationID == 0 && versionNumber == 0) else {
            throw IG.Error._invalid(applicationId: applicationID)
        }
        
        return (applicationID, version)
    }
}

extension Database {
    /// All migrations described in this database.
    internal enum Migration {
        /// Application ID "magic" number used to identify SQLite database files.
        internal static let applicationID: Int32 = 840797404
        
        /// The number of versions currently supported
        internal enum Version: Int, Comparable, CaseIterable {
            /// The version for database creation.
            case v0 = 0
            /// The initial version
            case v1 = 1
            
            /// The last described migration.
            static var latest: Self { Self.allCases.last! }
            
            /// Returns the next version from the current version.
            var next: Self? { Self.init(rawValue: self.rawValue + 1) }
            
            static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
        }
    }
}

extension Database.Migration {
    /// Returns the SQLite's file application ID "magic" number.
    /// - precondition: This should only be called from the database queue.
    /// - parameter database: The SQLite database connection.
    internal static func applicationID(database: SQLite.Database) throws -> Int32 {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        try sqlite3_prepare_v2(database, "PRAGMA application_id", -1, &statement, nil).expects(.ok) { IG.Error._invalidApplicationRetrieval(code: $0) }
        try sqlite3_step(statement).expects(.row) { IG.Error._applicationRetrievalFailed(code: $0) }
        return sqlite3_column_int(statement, 0)
    }
    
    /// Returns the database version for the given SQLite channel.
    /// - precondition: This should only be called from the database queue.
    /// - parameter database: The SQLite database connection.
    /// - returns: The number stored on the `PRAGMA user_version` field.
    internal static func version(database: SQLite.Database) throws -> Int {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        try sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil).expects(.ok) { IG.Error._invalidUserVersionRetrieval(code: $0) }
        try sqlite3_step(statement).expects(.row) { IG.Error._userVersionRetrievalFailed(code: $0) }
        return Int(sqlite3_column_int(statement, 0))
    }
    
    /// Sets the SQLite's file application ID "magic" number.
    /// - precondition: This should only be called from the database queue.
    /// - parameter applicationID: The application's magic number (i.e. identifier).
    /// - parameter database: The SQLite database connection.
    internal static func setApplicationID(_ applicationID: Int32, database: SQLite.Database) throws {
        try sqlite3_exec(database, "PRAGMA application_id = \(applicationID)", nil, nil, nil).expects(.ok) {
            IG.Error._applicationStorageFailed(code: $0)
        }
    }
    
    /// Sets the database user version number.
    /// - precondition: This should only be called from the database queue.
    /// - parameter version: The version number to be set to.
    /// - parameter database: The SQLite database connection.
    internal static func setVersion(_ version: Self.Version, database: SQLite.Database) throws {
        try sqlite3_exec(database, "PRAGMA user_version = \(version.rawValue)", nil, nil, nil).expects(.ok) {
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
