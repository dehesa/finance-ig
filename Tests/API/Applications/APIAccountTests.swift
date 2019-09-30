@testable import IG
import XCTest

/// Tests API Account related endpoints.
final class APIAccountTests: XCTestCase {
    /// Tests Account information retrieval.
    func testAccounts() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: acc.api.credentials, targetQueue: nil)
        
        let accounts = api.accounts.getAll().waitForOne()
        XCTAssertFalse(accounts.isEmpty)
        
        let account = accounts[0]
        XCTAssertEqual(account.identifier, api.session.credentials!.account)
        XCTAssertFalse(account.name.isEmpty)
        XCTAssertEqual(account.status, .enabled)
    }
    
    /// Tests Account update/retrieve.
    func testAccountPreferences() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: acc.api.credentials, targetQueue: nil)
        
        let initial = api.accounts.preferences().waitForOne()
        
        api.accounts.updatePreferences(trailingStops: !initial.trailingStops).wait()
        let updated = api.accounts.preferences().waitForOne()
        XCTAssertNotEqual(initial.trailingStops, updated.trailingStops)
        
        api.accounts.updatePreferences(trailingStops: initial.trailingStops).wait()
    }
}
