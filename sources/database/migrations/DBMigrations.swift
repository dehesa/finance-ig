import Foundation
import SQLite3

internal extension Database {
    /// Migrates the hosted database from its version to a targeted version.
    /// - parameter toVersion: The desired database version.
    /// - throws: `IG.Error` exclusively if the database is already on a higher version number or there were problems during migration.
    final func migrate(to toVersion: Database.Version) throws {
        var info = try self.info()
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
    final func migrateToLatestVersion() throws {
        var info = try self.info()
        
        while let nextVersion = info.version.next {
            try self._migrateToNextVersion()
            info.version = nextVersion
        }
    }
}

private extension Database {
    /// - precondition: The database version number is expected to be valid at this moment.
    /// - throws: `IG.Error` exclusively.
    final func _migrateToNextVersion() throws {
        switch Database.Version(rawValue: try self.channel.unrestrictedAccess { try $0.version() })! {
        case .v0: try Database.Migration.toVersion1(channel: self.channel)
        case .v1: try Database.Migration.toVersion2(channel: self.channel)
        case .v2: break
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
