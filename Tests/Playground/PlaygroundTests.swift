@testable import IG
import ReactiveSwift
import SQLite3
import XCTest

class PlaygroundTests: XCTestCase {
    func testApplicationRaw() {
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        print(db.rootURL)
    }
}
