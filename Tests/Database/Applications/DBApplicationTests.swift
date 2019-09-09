@testable import IG
import ReactiveSwift
import SQLite3
import XCTest

class DBApplicationTests: XCTestCase {
    /// Tests the creation of an "in-memory" database.
//    func testApplicationsInMemory() {
//        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
//
//    }
    
    func testApplicationRaw() {
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        var tableStatement: OpaquePointer? = nil
        sqlite3_prepare_v2(db.channel, IG.DB.Application.tableDefinition(for: .v0)!, -1, &tableStatement, nil)
        sqlite3_step(tableStatement)
        sqlite3_finalize(tableStatement)
        
        let data = """
        {
            "apiKey": "a12345bc67890d12345e6789fg0hi123j4567890",
            "name": "superlopez",
            "status": "ENABLED",
            "allowanceApplicationOverall": 60,
            "allowanceAccountTrading": 100,
            "allowanceAccountOverall": 60,
            "allowanceAccountHistoricalData": 10000,
            "concurrentSubscriptionsLimit": 40,
            "allowEquities": false,
            "allowQuoteOrders": false,
            "createdDate": "2018-10-16"
        }
        """.data(using: .utf8)!

        let appAPI = try! JSONDecoder().decode(IG.API.Application.self, from: data)
        print("\n\(appAPI.debugDescription)\n")

        try! db.applications.update([appAPI]).single()!.get()
        print()
        print("Update finished")
        print()
        
        let appsDB = try! db.applications.getAll().single()!.get()
        print(appsDB.first!)
    }
}
