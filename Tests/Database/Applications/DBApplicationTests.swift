@testable import IG
import ReactiveSwift
import GRDB
import XCTest

class DBApplicationTests: XCTestCase {
    /// Tests the creation of an "in-memory" database.
    func testApplicationsInMemory() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        let applications = try! api.applications.getAll().single()!.get()
        
        let database = try! IG.DB(rootURL: nil)
        var migrator = GRDB.DatabaseMigrator()
        IG.DB.Migration.register(on: &migrator)
        try! migrator.migrate(database.channel)
        
        try! database.applications.update(applications).single()!.get()
        
        let result = try! database.applications.getAll().single()!.get()
        print(result)
    }
}
