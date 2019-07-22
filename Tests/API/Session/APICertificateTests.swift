import XCTest
import ReactiveSwift
@testable import IG

/// Tests for the API CST endpoints.
final class APICertificateTests: APITestCase {
    /// Tests the CST lifecycle: session creation, refresh, and disconnection.
    func testCertificateLogInOut() {
        /// The info needed to request CST credentials.
        let info: (accountId: String, apiKey: String, username: String, password: String) = (self.account.accountId, self.account.api.key, self.account.api.username, self.account.api.password)
        
        let endpoints = self.api.session.loginCertificate(apiKey: info.apiKey, user: (info.username, info.password)).on(value: {
            XCTAssertGreaterThan($0.clientId, 0)
            XCTAssertEqual($0.apiKey, info.apiKey)
            XCTAssertEqual($0.accountId, info.accountId)
            XCTAssertGreaterThan($0.token.expirationDate, Date())
            
            guard case .certificate(let access, let security) = $0.token.value else {
                return XCTFail("Credentials were expected to be CST. Credentials received: \($0)")
            }
            XCTAssertFalse(access.isEmpty)
            XCTAssertFalse(security.isEmpty)
            
            let headers = $0.requestHeaders
            XCTAssertEqual(headers[.clientSessionToken], access)
            XCTAssertEqual(headers[.securityToken], security)
        }).call(on: self.api) { (api, credentials) in
            return api.session.logout()
        }.on(value: {
            XCTAssertNil(self.api.session.credentials)
        })

        self.test("Certificate Login procedure", endpoints, signingProcess: nil, timeout: 2)
    }
}
