import IG
import ConbiniForTesting
import XCTest

/// Tests API Account related endpoints.
final class APIAccountTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    /// Tests Account information retrieval.
    func testAccounts() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let accounts = api.accounts.getAll().expectsOne(timeout: 2, on: self)
        XCTAssertFalse(accounts.isEmpty)
        
        let account = accounts[0]
        XCTAssertEqual(account.id, api.session.credentials!.account)
        XCTAssertFalse(account.name.isEmpty)
        XCTAssertEqual(account.status, .enabled)
    }
    
    /// Tests Account update/retrieve.
    func testAccountPreferences() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let initial = api.accounts.getPreferences().expectsOne(timeout: 2, on: self)
        api.accounts.updatePreferences(trailingStops: !initial.trailingStops).expectsCompletion(timeout: 1.5, on: self)
        
        let updated = api.accounts.getPreferences().expectsOne(timeout: 2, on: self)
        XCTAssertNotEqual(initial.trailingStops, updated.trailingStops)
        
        api.accounts.updatePreferences(trailingStops: initial.trailingStops).expectsCompletion(timeout: 1.5, on: self)
    }
}
