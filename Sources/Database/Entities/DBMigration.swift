import Foundation

extension IG.DB {
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
        
        /// Registers all table on the SQLite database.
//        static func register(on migrator: inout GRDB.DatabaseMigrator) {
//            var migrations = Self.Version.allCases.makeIterator()
//            let errorMessage = "The migrator encountered an error"
//
//            guard case .v0 = migrations.next() else { fatalError(errorMessage) }
//            migrator.registerMigration(Self.Version.v0.rawValue) { (db) in
//                try IG.DB.Application.tableCreation(in: db)
//                try IG.DB.Market.tableCreation(in: db)
//                try IG.DB.Market.Forex.tableCreation(in: db)
////                try IG.DB.Node.tableCreation(in: db)
////                try IG.DB.Node.AssociativeMarket.tableCreation(in: db)
////                try IG.DB.Node.AssociativeSubnode.tableCreation(in: db)
//            }
//
//            guard case .none = migrations.next() else { fatalError("More migration awaited to be registered") }
//        }
    }
}
