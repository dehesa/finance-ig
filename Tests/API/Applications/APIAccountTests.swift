import XCTest
import ReactiveSwift
import Foundation
@testable import IG

/// Tests API Account related endpoints.
final class APIAccountTests: APITestCase {
    /// Tests Account information retrieval.
    func testAccounts() {
        let accountId = self.account.identifier
        
        let endpoint = self.api.accounts.getAll().on(value: {
            guard let account = $0.first else {
                return XCTFail("No accounts were found.")
            }
            XCTAssertEqual(account.identifier, accountId)
            XCTAssertFalse(account.name.isEmpty)
        })

        self.test("Accounts", endpoint, signingProcess: .oauth, timeout: 1)
    }
    
    /// Tests Account update/retrieve.
    func testAccountPreferences() {
        var initialTrailingStop: Bool! = nil

        let endpoint = self.api.accounts.preferences().on(value: {
            initialTrailingStop = $0.trailingStops
        }).call(on: self.api) { (api, preferences) -> SignalProducer<Void,API.Error> in
            api.accounts.updatePreferences(trailingStops: !preferences.trailingStops)
        }.call(on: self.api) { (api, _) -> SignalProducer<API.Account.Preferences,API.Error> in
            api.accounts.preferences()
        }.on(value: {
            XCTAssertNotEqual($0.trailingStops, initialTrailingStop)
        }).call(on: self.api) { (api, _) -> SignalProducer<Void,API.Error> in
            api.accounts.updatePreferences(trailingStops: initialTrailingStop)
        }

        self.test("Account Preferences", endpoint, signingProcess: .oauth, timeout: 2)
    }
}
