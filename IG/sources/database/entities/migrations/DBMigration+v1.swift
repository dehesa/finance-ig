import Foundation
import SQLite3

extension Database.Migration {
    /// Where the actual migration happens.
    /// - parameter channel: The SQLite database connection.
    /// - throws: `IG.Error` exclusively.
    internal static func initialMigration(channel: Database.Channel) throws {
        try channel.write { (database) throws -> Void in
            // Set the application identifier for the database
            try Self.setApplicationID(Self.applicationID, database: database)
            
            let types: [DBTable.Type] = [Database.Application.self, Database.Market.self, Database.Market.Forex.self]
            // Create all tables
            for type in types {
                try sqlite3_exec(database, type.tableDefinition, nil, nil, nil).expects(.ok) {
                    IG.Error(.database(.callFailed), "The SQL statement to create a table for '\(type.self)' failed to execute", info: ["Error code": $0])
                }
            }
            
            // Set the version number to first version.
            try Self.setVersion(.v1, database: database)
        }
    }
}
