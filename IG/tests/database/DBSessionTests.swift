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

private extension String {
    private static let _lowercaseASCII = "abcdefghijklmnopqrstuvwxyz"
    private static let _uppercaseASCII = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let _numbers = "0123456789"
    
    static func random(length: Int) -> String {
        let pool = _lowercaseASCII.appending(_uppercaseASCII)
        return .init((0..<length).map { _ in pool.randomElement().unsafelyUnwrapped })
    }
}
