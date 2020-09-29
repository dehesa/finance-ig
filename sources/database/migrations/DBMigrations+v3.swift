import Foundation
import SQLite3

extension Database.Migration {
    /// Migration from v2 to v3.
    ///
    /// This migration simply add a new "central bank interest rate" table.
    /// - parameter channel: The SQLite database connection.
    /// - throws: `IG.Error` exclusively.
    internal static func toVersion3(channel: Database.Channel) throws {
        try channel.write { (database) throws -> Void in
            /// Create the interest rate table.
            try sqlite3_exec(database, Database.InterestRate.tableDefinition, nil, nil, nil).expects(.ok) {
                IG.Error._tableCreationFailed(code: $0)
            }
            // Set the new version number.
            try database.set(version: .v3)
        }
    }
}

private extension IG.Error {
    /// Error raised when a SQLite table cannot be created.
    static func _tableCreationFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The SQL statement to create an interest rate table failed to execute", info: ["Error code": code])
    }
}
