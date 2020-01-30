@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API Account related endpoints.
final class APIAccountTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests Account information retrieval.
    func testAccounts() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let accounts = api.accounts.getAll()
            .expectsOne(timeout: 2, on: self)
        XCTAssertFalse(accounts.isEmpty)
        
        let account = accounts[0]
        XCTAssertEqual(account.identifier, api.session.credentials!.account)
        XCTAssertFalse(account.name.isEmpty)
        XCTAssertEqual(account.status, .enabled)
    }
    
    /// Tests Account update/retrieve.
    func testAccountPreferences() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
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
