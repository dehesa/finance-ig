@testable import IG
import XCTest

/// Tests for the API CST endpoints.
final class APICertificateTests: XCTestCase {
    /// Tests the CST lifecycle: session creation, refresh, and disconnection.
    func testCertificateLogInOut() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: nil, targetQueue: nil)
        
        guard let user = acc.api.user else {
            return XCTFail("OAuth tests can't be performed without username and password")
        }
        
        let (credentials, _): (API.Credentials, API.Session.Settings) = api.session.loginCertificate(key: acc.api.key, user: user)
            .expectsSuccess { self.wait(for: [$0], timeout: 2) }
        XCTAssertFalse(credentials.client.rawValue.isEmpty)
        XCTAssertEqual(credentials.key, acc.api.key)
        XCTAssertEqual(credentials.account, acc.identifier)
        XCTAssertFalse(credentials.token.isExpired)
        guard case .certificate(let access, let security) = credentials.token.value else {
            return XCTFail("Credentials were expected to be CST. Credentials received: \(credentials)")
        }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(security.isEmpty)
        
        let headers = credentials.requestHeaders
        XCTAssertEqual(headers[.clientSessionToken], access)
        XCTAssertEqual(headers[.securityToken], security)
        
        api.session.credentials = credentials
        api.session.logout()
            .expectsCompletion { self.wait(for: [$0], timeout: 1) }
        XCTAssertNil(api.session.credentials)
    }
    
    /// Tests the refresh functionality.
    func testRefreshCertificates() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: nil, targetQueue: nil)
        
        guard let user = acc.api.user else {
            return XCTFail("OAuth tests can't be performed without username and password")
        }
        
        let credentials = api.session.loginOAuth(key: acc.api.key, user: user)
            .expectsSuccess { self.wait(for: [$0], timeout: 2) }
        guard case .oauth = credentials.token.value else {
            return XCTFail("Credentials were expected to be OAuth. Credentials received: \(credentials)")
        }
        XCTAssertFalse(credentials.token.isExpired)
        api.session.credentials = credentials

        let token = api.session.refreshCertificate()
            .expectsSuccess { self.wait(for: [$0], timeout: 2) }
        guard case .certificate(let access, let security) = token.value else { return XCTFail("A certificate token hasn't been regenerated") }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(security.isEmpty)
        XCTAssertFalse(token.isExpired)
    }
}
