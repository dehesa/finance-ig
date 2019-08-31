import XCTest
@testable import IG

class DBSessionTests: XCTestCase {
    /// Tests the creation of an "in-memory" database.
    func testDatabaseInMemory() {
        let database = try! IG.DB(rootURL: nil)
        XCTAssertEqual(database.channel.path, ":memory:")
    }
    
    /// Tests the creation of a File-System database.
    func testDatabaseCreation() {
        let database = Test.makeDatabase()
        if let url = Test.account.database?.rootURL {
            XCTAssertEqual(database.channel.path, url.path)
        }
    }
}
