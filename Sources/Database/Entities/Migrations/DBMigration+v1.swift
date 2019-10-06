import SQLite3
import Foundation

extension IG.DB.Migration {
    /// Where the actual migration happens.
    /// - parameter channel: The SQLite database connection.
    /// - throws: `IG.DB.Error` exclusively.
    internal static func initialMigration(channel: IG.DB.Channel) throws {
        try channel.write { (database) throws -> Void in
            // Set the application identifier for the database
            try Self.setApplicationID(Self.applicationID, database: database)
            
            #warning("DB: Uncomment")
            let types: [(IG.DBTable & IG.DebugDescriptable).Type] = [IG.DB.Application.self/*, IG.DB.Market.self, IG.DB.Market.Forex.self*/]
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
