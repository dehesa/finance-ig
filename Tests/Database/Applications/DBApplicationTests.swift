@testable import IG
import ReactiveSwift
import XCTest

class DBApplicationTests: XCTestCase {
//    /// Tests the creation of an "in-memory" database.
//    func testApplicationsInMemory() {
//        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api)
//        let appsAPI = try! api.applications.getAll().single()!.get()
//        print()
//        print(appsAPI.first!)
//        print()
//
//        let database = try! IG.DB(rootURL: nil)
//        var migrator = GRDB.DatabaseMigrator()
//        IG.DB.Migration.register(on: &migrator)
//        try! migrator.migrate(database.channel)
//
//        try! database.applications.update(appsAPI).single()!.get()
//        let appsDB = try! database.applications.getAll().single()!.get()
//        print(appsDB.first!)
//
//        XCTAssertEqual(appsAPI.count, appsDB.count)
//        for (api, db) in zip(appsAPI, appsDB) {
//            XCTAssertEqual(api.key, db.key)
//            XCTAssertEqual(api.name, db.name)
//            XCTAssertEqual(api.permission.accessToEquityPrices, db.permission.accessToEquityPrices)
//            XCTAssertEqual(api.creationDate, db.created)
//        }
//    }
    
//    func testApplicationRaw() {
//        let data = """
//        {
//            "name": "dehesa",
//            "apiKey": "a24209ef60976d82936e4649bc9dc775b9520611",
//            "status": "ENABLED",
//            "allowanceApplicationOverall": 60,
//            "allowanceAccountTrading": 100,
//            "allowanceAccountOverall": 60,
//            "allowanceAccountHistoricalData": 10000,
//            "concurrentSubscriptionsLimit": 40,
//            "allowEquities": false,
//            "allowQuoteOrders": false,
//            "createdDate": "2018-05-16"
//        }
//        """.data(using: .utf8)!
//
//        let encodedApp = try! JSONDecoder().decode(IG.API.Application.self, from: data)
//        print("\n\(encodedApp.debugDescription)\n")
//
//        let database = try! IG.DB(rootURL: nil)
//        try! database.channel.write {
//            try $0.execute(sql: IG.DB.Application.tableDefinition(for: .last)!)
//
//        }
//        try! database.applications.update([encodedApp]).single()!.get()
//
//        let storedApp = try! database.applications.getAll().single()!.get()
//        print(storedApp)
//        print()
//    }
}
