import XCTest
import ReactiveSwift
import Foundation

/// Tests API Account related endpoints.
final class APIAccountTests: APITestCase {
    /// Tests Account information retrieval.
    func testAccounts() {
        let loginData = APITestCase.loginData(account: self.account)
        
        let endpoint = self.api.accounts().on(value: {
            XCTAssertFalse($0.isEmpty)
            
            let account = $0.first!
            XCTAssertEqual(account.identifier, loginData.accountId)
            XCTAssertFalse(account.name.isEmpty)
            XCTAssertFalse(account.currency.isEmpty)
        })

        self.test("Accounts", endpoint, signingProcess: .oauth, timeout: 1)
    }
    
    /// Tests Account update/retrieve.
    func testAccountPreferences() {
        let endpoint = self.api.accountPreferences()
        
        self.test("Account Preferences", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
