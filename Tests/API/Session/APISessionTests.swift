import XCTest
import ReactiveSwift
@testable import IG

/// Tests API Session related endpoints.
final class APISessionTests: APITestCase {
    /// Tests the Session information retrieval mechanisms.
    func testSession() {
        let info: (accountId: String, apiKey: String, username: String, password: String) = (self.account.accountId, self.account.api.key, self.account.api.username, self.account.api.password)
        
        let endpoints = self.api.session.login(type: .oauth, apiKey: info.apiKey, user: (info.username, info.password))
            .call(on: self.api) { (api, credentials) -> SignalProducer<API.Session,API.Error> in
                return api.session.get()
            }.on(value: { (response) in
                XCTAssertGreaterThan(response.clientId, 0)
                XCTAssertEqual(response.accountId, info.accountId)
                XCTAssertNotNil(response.streamerURL.scheme)
                XCTAssertEqual(response.streamerURL.scheme!, "https")
                XCTAssertEqual(response.currency.count, 3)
            }).call(on: self.api) { (api, _) in
                api.session.logout()
            }
        
        self.test("Session lifecycle", endpoints, signingProcess: nil, timeout: 2)
    }
}
