import XCTest
import ReactiveSwift
@testable import IG

/// Tests for the API CST endpoints.
final class APICertificateTests: APITestCase {
    /// Tests the CST lifecycle: session creation, refresh, and disconnection.
    func testCertificateLogInOut() {
        // The info needed to request CST credentials.
        let info = APITestCase.loginData(account: self.account)
        
        let endpoints = api.certificateLogin(info).on(value: {
            XCTAssertGreaterThan($0.apiKey.count, 0)
            XCTAssertGreaterThan($0.clientId, 0)
            XCTAssertEqual($0.accountId, info.accountId)
            XCTAssertGreaterThan($0.token.expirationDate, Date())
            
            guard case .certificate(let access, let security) = $0.token.value else {
                return XCTFail("Credentials were expected to be CST. Credentials received: \($0)")
            }
            XCTAssertFalse(access.isEmpty)
            XCTAssertFalse(security.isEmpty)
            
            let headers = $0.requestHeaders
            XCTAssertNotNil(headers[.clientSessionToken])
            XCTAssertNotNil(headers[.securityToken])
        }).call(on: self.api) { (api, credentials) in
            api.updateCredentials(credentials)
            return api.sessionLogout()
        }.on(value: {
            XCTAssertNil(try? self.api.credentials())
        })

        self.test("Certificate Login procedure", endpoints, timeout: 2)
    }
}
