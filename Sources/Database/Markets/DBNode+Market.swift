import GRDB
import Foundation

extension IG.DB.Node {
    /// Associative table listing nodes and their owned markets.
    /// - A node can have none or many markets.
    /// - A market is owned by one or many nodes.
    internal struct AssociativeMarket {
        /// Let through the hidden `rowId` column
        private(set) var identifier: Int64?
        /// A targeted node.
        let nodeIdentifier: String
        /// A node's market.
        let marketEpic: String
    }
}

extension IG.DB.Node.AssociativeMarket {
    static func tableCreation(in db: GRDB.Database) throws {
        typealias N = IG.DB.Node
        typealias M = IG.DB.Market.Forex
        
        try db.create(table: "nodesMarket", ifNotExists: false) { (t) in
            t.autoIncrementedPrimaryKey("id")
            t.column("nodeId", .text).notNull().references(N.databaseTableName, column: N.Columns.identifier.rawValue, onDelete: .cascade)
            t.column("epic", .text)  .notNull().references(M.databaseTableName, column: M.Columns.epic.rawValue, onDelete: .cascade)
        }
    }
}

extension IG.DB.Node.AssociativeMarket: GRDB.FetchableRecord, GRDB.MutablePersistableRecord {
    public init(row: Row) {
        self.identifier = row[0]
        self.nodeIdentifier = row[1]
        self.marketEpic = row[2]
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[Columns.identifier] = self.identifier
        container[Columns.nodeIdentifier] = self.nodeIdentifier
        container[Columns.marketEpic] = self.marketEpic
    }
    
    // Update a player id after it has been inserted in the database.
    mutating func didInsert(with rowID: Int64, for column: String?) {
        self.identifier = rowID
    }
}

extension IG.DB.Node.AssociativeMarket: GRDB.TableRecord {
    /// The table columns
    private enum Columns: String, GRDB.ColumnExpression {
        case identifier = "id"
        case nodeIdentifier = "nodeId"
        case marketEpic = "epic"
    }
    
    public static var databaseTableName: String {
        return "nodes_markets"
    }
    
    //public static var databaseSelection: [SQLSelectable] { [AllColumns()] }
}
