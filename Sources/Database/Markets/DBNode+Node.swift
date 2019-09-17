import Foundation

extension IG.DB.Node {
    /// Associative table listing nodes and subnodes.
    /// - A node can have none or many subnodes.
    /// - A subnode can be owned by one or many parent nodes.
    internal struct AssociativeSubnode {
        /// Let through the hidden `rowId` column
        private(set) var identifier: Int64?
        /// The parent node.
        let parentIdentifier: String
        /// A child node from the parent node.
        let childIdentifier: String
    }
}

//extension IG.DB.Node.AssociativeSubnode {
//    static func tableCreation(in db: GRDB.Database) throws {
//        typealias N = IG.DB.Node
//
//        try db.create(table: "nodesMarket", ifNotExists: false) { (t) in
//            t.autoIncrementedPrimaryKey("id")
//            t.column("parentId", .text).notNull().indexed().references(N.databaseTableName, column: N.Columns.identifier.rawValue, onDelete: .cascade)
//            t.column("childId", .text) .notNull().references(N.databaseTableName, column: N.Columns.identifier.rawValue, onDelete: .cascade)
//            t.check(Self.Columns.parentIdentifier != Self.Columns.childIdentifier)
//        }
//    }
//}
//
//extension IG.DB.Node.AssociativeSubnode: GRDB.FetchableRecord, GRDB.MutablePersistableRecord {
//    public init(row: GRDB.Row) {
//        self.identifier = row[0]
//        self.parentIdentifier = row[1]
//        self.childIdentifier = row[2]
//    }
//
//    func encode(to container: inout GRDB.PersistenceContainer) {
//        container[Columns.identifier] = self.identifier
//        container[Columns.parentIdentifier] = self.parentIdentifier
//        container[Columns.childIdentifier] = self.childIdentifier
//    }
//
//    // Update a player id after it has been inserted in the database.
//    mutating func didInsert(with rowID: Int64, for column: String?) {
//        self.identifier = rowID
//    }
//}
//
//extension IG.DB.Node.AssociativeSubnode: GRDB.TableRecord {
//    /// The table columns
//    private enum Columns: String, GRDB.ColumnExpression {
//        case identifier = "id"
//        case parentIdentifier = "parentId"
//        case childIdentifier = "childId"
//    }
//
//    public static var databaseTableName: String {
//        return "nodes_subnodes"
//    }
//
//    //public static var databaseSelection: [SQLSelectable] { [AllColumns()] }
//}
