@testable import IG
import XCTest

/// Tests API Account related endpoints.
final class APIAccountTests: XCTestCase {
    /// Tests Account information retrieval.
    func testAccounts() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let accounts = api.accounts.getAll()
            .expectsOne(timeout: 2, on: self)
        XCTAssertFalse(accounts.isEmpty)
        
        let account = accounts[0]
        XCTAssertEqual(account.identifier, api.session.account!)
        XCTAssertFalse(account.name.isEmpty)
        XCTAssertEqual(account.status, .enabled)
    }
    
    /// Tests Account update/retrieve.
    func testAccountPreferences() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let initial = api.accounts.preferences()
            .expectsOne(timeout: 2, on: self)
        
        api.accounts.updatePreferences(trailingStops: !initial.trailingStops)
            .expectsCompletion(timeout: 1.5, on: self)
        let updated = api.accounts.preferences()
            .expectsOne(timeout: 2, on: self)
        XCTAssertNotEqual(initial.trailingStops, updated.trailingStops)
        
        api.accounts.updatePreferences(trailingStops: initial.trailingStops)
            .expectsCompletion(timeout: 1.5, on: self)
    }
}
