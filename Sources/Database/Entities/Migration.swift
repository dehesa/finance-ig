import GRDB
import Foundation

extension IG.Database {
    /// All migrations described in this database.
    enum Migration {
        /// The number of versions currently supported
        enum Version: String, Equatable, CaseIterable {
            /// The initial migration.
            case v0 = "v0"
            
            /// The last described migration.
            static var last: Self {
                return Self.allCases.last!
            }
        }
        
        ///
        static func register(on migrator: inout GRDB.DatabaseMigrator) {
            typealias DB = IG.Database
            var migrations = Self.Version.allCases.makeIterator()
            let errorMessage = "The migrator encountered an error."
            
            guard case .v0 = migrations.next() else { fatalError(errorMessage) }
            migrator.registerMigration("v0") { (db) in
                try DB.Application.tableCreation(in: db)
            }
            
            guard case .none = migrations.next() else { fatalError("More migration awaited to be registered.") }
        }
    }
}
