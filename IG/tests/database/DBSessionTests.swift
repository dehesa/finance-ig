import XCTest
import IG

final class DBSessionTests: XCTestCase {
    /// Tests the creation of an "in-memory" database.
    func testDatabaseInMemory() {
        let database = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        XCTAssertNil(database.rootURL)
    }
    
    /// Tests the creation of a File-System database.
    func testDatabaseFile() {
        let fileName = String.random(length: Int.random(in: 8...13)).appending(".sqlite")
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName, isDirectory: false)

        var database: Database? = Test.makeDatabase(rootURL: fileURL, targetQueue: nil)
        XCTAssertNotNil(database?.rootURL)
        XCTAssertEqual(database!.rootURL!, fileURL.absoluteURL)

        database = nil
        try! FileManager.default.removeItem(at: fileURL)
    }
}
