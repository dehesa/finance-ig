import GRDB
import Foundation

extension IG.DB {
    /// Database representation of the IG's platform navigation node.
    public struct Node {
        /// Node identifier.
        public let identifier: String
        /// Node's name.
        public let name: String?
        
//        static let subnodes = hasMany(Self.self, key: "children", using: .init(<#T##originColumns: [ColumnExpression]##[ColumnExpression]#>, to: <#T##[ColumnExpression]?#>))
    }
}

// MARK: - GRDB Internals

extension IG.DB.Node {
    /// Creates a SQLite table for Forex markets.
    static func tableCreation(in db: GRDB.Database) throws {
        try db.create(table: "nodes", ifNotExists: false, withoutRowID: true) { (t) in
            t.column("nodeId", .text).primaryKey()
            t.column("name", .text)  .collate(.unicodeCompare)
        }
    }
}

extension IG.DB.Node: GRDB.FetchableRecord, GRDB.PersistableRecord {
    public init(row: Row) {
        self.identifier = row[0]
        self.name = row[1]
    }
    
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.identifier] = self.identifier
        container[Columns.name] = self.name
    }
}

extension IG.DB.Node: GRDB.TableRecord {
    /// The SQLite table columns.
    internal enum Columns: String, GRDB.ColumnExpression {
        case identifier = "nodeId"
        case name = "name"
    }
    
    public static var databaseTableName: String {
        return "nodes"
    }
    
    //public static var databaseSelection: [SQLSelectable] { [AllColumns()] }
}
