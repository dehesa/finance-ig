@testable import IG
import ReactiveSwift
import GRDB
import XCTest

class DBApplicationTests: XCTestCase {
    /// Tests the creation of an "in-memory" database.
    func testApplicationsInMemory() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        let appsAPI = try! api.applications.getAll().single()!.get()
        print()
        print(appsAPI.first!)
        print()
        
        let database = try! IG.DB(rootURL: nil)
        var migrator = GRDB.DatabaseMigrator()
        IG.DB.Migration.register(on: &migrator)
        try! migrator.migrate(database.channel)
        
        try! database.applications.update(appsAPI).single()!.get()
        let appsDB = try! database.applications.getAll().single()!.get()
        print(appsDB.first!)
        
        XCTAssertEqual(appsAPI.count, appsDB.count)
        for (api, db) in zip(appsAPI, appsDB) {
            XCTAssertEqual(api.key, db.key)
            XCTAssertEqual(api.name, db.name)
            XCTAssertEqual(api.permission.accessToEquityPrices, db.permission.accessToEquityPrices)
            XCTAssertEqual(api.creationDate, db.created)
        }
    }
}
