import XCTest
import ReactiveSwift
@testable import IG

/// Tests API Session related endpoints.
final class APISessionTests: APITestCase {
    /// Tests the Session information retrieval mechanisms.
    func testSession() {
        let info: (accountId: String, apiKey: String) = (self.account.identifier, self.account.api.key)
        
        let endpoints = self.api.session.login(type: .oauth, apiKey: info.apiKey, user: self.account.api.user)
            .call(on: self.api) { (api, credentials) -> SignalProducer<API.Session,API.Error> in
                return api.session.get()
            }.on(value: { (response) in
                XCTAssertGreaterThan(response.clientId, 0)
                XCTAssertEqual(response.accountId, info.accountId)
                XCTAssertNotNil(response.streamerURL.scheme)
                XCTAssertEqual(response.streamerURL.scheme!, "https")
            }).call(on: self.api) { (api, _) in
                api.session.logout()
            }
        
        self.test("Session lifecycle", endpoints, signingProcess: nil, timeout: 2)
    }
}
