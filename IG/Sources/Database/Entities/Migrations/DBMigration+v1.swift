import Foundation
import SQLite3

extension IG.Database.Migration {
    /// Where the actual migration happens.
    /// - parameter channel: The SQLite database connection.
    /// - throws: `IG.Database.Error` exclusively.
    internal static func initialMigration(channel: IG.Database.Channel) throws {
        try channel.write { (database) throws -> Void in
            // Set the application identifier for the database
            try Self.setApplicationID(Self.applicationID, database: database)
            
            let types: [(IG.DBTable & IG.DebugDescriptable).Type] = [IG.Database.Application.self, IG.Database.Market.self, IG.Database.Market.Forex.self]
            // Create all tables
            for type in types {
                try sqlite3_exec(database, type.tableDefinition, nil, nil, nil).expects(.ok) {
                    .callFailed(.init(#"The SQL statement to create a table for "\#(type.printableDomain)" failed to execute"#), code: $0)
                }
            }
            
            // Set the version number to first version.
            try Self.setVersion(.v1, database: database)
        }
    }
}
