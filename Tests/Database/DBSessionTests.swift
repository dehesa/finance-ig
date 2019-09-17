@testable import IG
import XCTest
import SQLite3

final class DBSessionTests: XCTestCase {
    /// Tests the creation of an "in-memory" database.
    func testDatabaseInMemory() {
        let database = try! IG.DB(rootURL: nil, targetQueue: nil)
        print(database)
    }
    
    /// Tests the creation of a File-System database.
    func testDatabaseFile() {
        let fileName = String.random(length: Int.random(in: 8...13)).appending(".sqlite")
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName, isDirectory: false)
        
        var database: IG.DB? = Test.makeDatabase(rootURL: fileURL, targetQueue: nil)
        XCTAssertEqual(database!.rootURL!, fileURL.absoluteURL)
        
        database = nil
        try! FileManager.default.removeItem(at: fileURL)
    }
}
