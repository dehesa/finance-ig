@testable import IG
import ReactiveSwift
import XCTest

final class DBNodeTests: XCTestCase {
    /// Tests the creation of an "in-memory" database.
    func testNodeTableCreation() {
//        let database = try! Database(rootURL: nil)
//        
//        let queue = database.channel
//        try! queue.write { (db) in
//            try Database.Market.Node.tableCreation(in: db)
//        }
//
//        typealias Node = Database.Market.Node
//        let nodes: [Node] = [
//            .init(id: "0", name: "Root", subnodes: ["1", "2", "3"], markets: []),
//            .init(id: "1", name: "Europe", subnodes: [], markets: ["EUR.USD", "EUR.CAD"]),
//            .init(id: "2", name: "United States", subnodes: [], markets: ["GBP.USD", "USD.CAD"])
//        ]
//
//        try! queue.write { (db) in
//            for node in nodes {
//                try node.save(db)
//            }
//        }
//
//        let result = try! queue.read { (db) in
//            return try Node.fetchAll(db)
//        }
//
//        print(result)
    }

//    /// Tests the creation of a File-System database.
//    func testDatabaseCreation() {
//        let database = Test.makeDatabase(rootURL: Self.account.database?.rootURL)
//        if let url = Test.account.database?.rootURL {
//            XCTAssertEqual(database.channel.path, url.path)
//        }
//    }
}
