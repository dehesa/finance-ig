import Foundation
import SQLite3

extension IG.DB {
    /// All migrations described in this database.
    internal enum Migration {
        /// The number of versions currently supported
        internal enum Version: String, Equatable, CaseIterable {
            /// The initial migration.
            case v0 = "v0"
        }
        
        /// Apply the migrations till (and including) the given version.
        ///
        /// This function will check the version of your database and migrate till the given version.
        /// - warning: This function will perform a `queue.sync()` operation. Be sure no deadlocks occurs.
        /// - parameter version: The last version to migrate your database to.
        /// - parameter channel: The database connection pointer.
        /// - parameter queue: The priviledge database queue.
        /// - throws: `IG.DB.Error` exclusively.
        internal static func apply(untilVersion version: Self.Version, for channel: SQLite.Database, on queue: DispatchQueue) throws {
            switch version {
            case .v0: try Self.initialVersion(version, channel: channel, queue: queue)
            }
        }
    }
}

internal protocol DBMigratable {
    /// Returns a SQL definition for the receiving type on the specific database version.
    static func tableDefinition(for version: IG.DB.Migration.Version) -> String?
}

extension IG.DB.Migration {
    private typealias MigrationType = DBMigratable & DebugDescriptable
    
    /// Where the actual migration happens.
    private static func initialVersion(_ version: Self.Version, channel: SQLite.Database, queue: DispatchQueue) throws {
        let types: [MigrationType.Type] = [IG.DB.Application.self, IG.DB.Market.self, IG.DB.Market.Forex.self]
        
        sqlite3_exec(channel, "BEGIN TRANSACTION", nil, nil, nil)
        
        var isRollbackNeeded = false
        defer {
            let statement = (isRollbackNeeded == false) ? "END TRANSACTION" : "ROLLBACK"
            sqlite3_exec(channel, statement, nil, nil, nil)
        }
        
        for type in types {
            guard let sql = type.tableDefinition(for: version) else {
                isRollbackNeeded = true
                throw IG.DB.Error.invalidRequest(.sqlNotFound(for: type, version: version), suggestion: .reviewError)
            }
            
            if let creationError = sqlite3_exec(channel, sql, nil, nil, nil).enforce(.ok) {
                isRollbackNeeded = true
                throw IG.DB.Error.callFailed(.tableCreation(for: type), code: creationError)
            }
        }
    }
}

extension IG.DB.Migration.Version {
    /// The last described migration.
    static var latest: Self {
        return Self.allCases.last!
    }
}
