import XCTest
import IG

final class DBSessionTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the creation of an "in-memory" database.
    func testDatabaseInMemory() throws {
        let database = try Database(location: .memory)
        XCTAssertNil(database.rootURL)
    }
    
    /// Tests the creation of a File-System database.
    func testDatabaseFile() throws {
        let fileName = String.random(length: Int.random(in: 8...13)).appending(".sqlite")
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName, isDirectory: false)

        var database: Database? = try Database(location: .file(url: fileURL, expectsExistance: false))
        XCTAssertNotNil(database?.rootURL)
        XCTAssertEqual(database!.rootURL!, fileURL.absoluteURL)

        database = nil
        try! FileManager.default.removeItem(at: fileURL)
    }
}
