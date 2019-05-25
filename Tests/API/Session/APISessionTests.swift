import XCTest
import ReactiveSwift
@testable import IG

/// Tests API Session related endpoints.
final class APISessionTests: APITestCase {
    /// Tests the Session information retrieval mechanisms.
    func testSession() {
        let info = APITestCase.loginData(account: self.account)
        
        let endpoints = self.api.sessionLogin(info, type: .oauth)
            .call(on: self.api) { (api, credentials) -> SignalProducer<API.Response.Session,API.Error> in
                api.updateCredentials(credentials)
                return api.session()
            }.on(value: { (response) in
                XCTAssertGreaterThan(response.clientId, 0)
                XCTAssertEqual(response.accountId, info.accountId)
                XCTAssertNotNil(response.streamerURL.scheme)
                XCTAssertEqual(response.streamerURL.scheme!, "https")
                XCTAssertEqual(response.currency.count, 3)
            }).call(on: self.api) { (api, _) in
                api.sessionLogout()
            }
        
        self.test("Session lifecycle", endpoints, timeout: 2)
    }
    
    /// Tests the retrieval of encryption keys.
    func testEncryption() {
        let apiKey = APITestCase.loginData(account: self.account).apiKey
        
        let now = Date()
        
        let endpoint = self.api.sessionEncryptionKey(apiKey: apiKey).on(value: {
            XCTAssertFalse($0.key.isEmpty)
            XCTAssertGreaterThan($0.timeStamp, now)
        })
        
        self.test("Session encryption key", endpoint, signingProcess: .oauth, timeout: 2)
    }
}
