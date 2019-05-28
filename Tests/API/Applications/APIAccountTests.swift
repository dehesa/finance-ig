import XCTest
import ReactiveSwift
import Foundation
@testable import IG

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
        var initialTrailingStop: Bool! = nil
        
        let endpoint = self.api.accountPreferences().on(value: {
            XCTAssertTrue($0.trailingStops)
            initialTrailingStop = $0.trailingStops
        }).call(on: self.api) { (api, preferences) -> SignalProducer<Void,API.Error> in
            api.updateAccountPreferences(trailingStops: !preferences.trailingStops)
        }.call(on: self.api) { (api, initialTrailingStop) -> SignalProducer<API.Response.Account.Preferences,API.Error> in
            api.accountPreferences()
        }.on(value: {
            XCTAssertNotEqual(initialTrailingStop, $0.trailingStops)
        }).call(on: self.api) { (api, _) -> SignalProducer<Void,API.Error> in
            api.updateAccountPreferences(trailingStops: initialTrailingStop)
        }
        
        self.test("Account Preferences", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
