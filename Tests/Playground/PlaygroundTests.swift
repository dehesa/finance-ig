@testable import IG
import ReactiveSwift
import SQLite3
import XCTest

final class PlaygroundTests: XCTestCase {
    func testPlay() {
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        
        var tableStatement: OpaquePointer? = nil
        sqlite3_prepare_v2(db.channel, IG.DB.Application.tableDefinition(for: .v0)!, -1, &tableStatement, nil)
        sqlite3_step(tableStatement)
        sqlite3_finalize(tableStatement)
        
        var statement: OpaquePointer? = nil
        let definition: String = """
        INSERT OR REPLACE INTO Apps VALUES (
            'i12848vk82599t79948l0635gz3oi786v9095129',
            'superlopez',
            '1',
            '0',
            '0',
            '60',
            '60',
            '100',
            '10000',
            '60',
            '2019-09-09',
            CURRENT_TIMESTAMP);
        """
        guard case .ok = sqlite3_prepare_v2(db.channel, definition, -1, &statement, nil) else { fatalError() }
        
        guard case .done = sqlite3_step(statement).result else { fatalError() }
        sqlite3_finalize(statement)
        
        print()
        print()
    }
}
