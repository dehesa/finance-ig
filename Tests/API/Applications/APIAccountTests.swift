@testable import IG
import ReactiveSwift
import XCTest

/// Tests API Account related endpoints.
final class APIAccountTests: XCTestCase {
    /// Tests Account information retrieval.
    func testAccounts() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        let accounts = try! api.accounts.getAll().single()!.get()
        
        let account = accounts.first!
        XCTAssertEqual(account.identifier, api.session.credentials!.account)
        XCTAssertFalse(account.name.isEmpty)
        XCTAssertEqual(account.status, .enabled)
    }
    
    /// Tests Account update/retrieve.
    func testAccountPreferences() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        let initial = try! api.accounts.preferences().single()!.get()
        
        try! api.accounts.updatePreferences(trailingStops: !initial.trailingStops).single()!.get()
        let updated = try! api.accounts.preferences().single()!.get()
        XCTAssertNotEqual(initial.trailingStops, updated.trailingStops)
        
        try! api.accounts.updatePreferences(trailingStops: initial.trailingStops).single()!.get()
    }
}
