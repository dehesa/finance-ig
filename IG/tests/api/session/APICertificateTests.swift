@testable import IG
import ConbiniForTesting
import XCTest

/// Tests for the API CST endpoints.
final class APICertificateTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests the CST lifecycle: session creation, refresh, and disconnection.
    func testCertificateLogInOut() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: nil, targetQueue: nil)
        // Check the API is set up with the test user
        guard let user = self._acc.api.user else {
            return XCTFail("OAuth tests can't be performed without username and password")
        }
        // Log in through certificate credentials with the test account
        let (credentials, _): (API.Credentials, API.Session.Settings) = api.session.loginCertificate(key: self._acc.api.key, user: user).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(credentials.client.rawValue.isEmpty)
        XCTAssertEqual(credentials.key, self._acc.api.key)
        XCTAssertEqual(credentials.account, self._acc.identifier)
        XCTAssertFalse(credentials.token.isExpired)
        guard case .certificate(let access, let security) = credentials.token.value else {
            return XCTFail("Credentials were expected to be CST. Credentials received: \(credentials)")
        }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(security.isEmpty)
        // Generate a typical request header
        let headers = credentials.requestHeaders
        XCTAssertEqual(headers[.clientSessionToken], access)
        XCTAssertEqual(headers[.securityToken], security)
        
        api.channel.credentials = credentials
        api.session.logout().expectsCompletion(timeout: 1, on: self)
        XCTAssertNil(api.channel.credentials)
    }
    
    /// Tests the refresh functionality.
    func testRefreshCertificates() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: nil, targetQueue: nil)
        // Check the API is set up with the test user
        guard let user = self._acc.api.user else {
            return XCTFail("OAuth tests can't be performed without username and password")
        }
        // Log in through certificate credentials with the test account
        let credentials = api.session.loginOAuth(key: self._acc.api.key, user: user).expectsOne(timeout: 2, on: self)
        guard case .oauth = credentials.token.value else {
            return XCTFail("Credentials were expected to be OAuth. Credentials received: \(credentials)")
        }
        XCTAssertFalse(credentials.token.isExpired)
        api.channel.credentials = credentials
        // Refresh the certificate token.
        let token = api.session.refreshCertificate().expectsOne(timeout: 2, on: self)
        guard case .certificate(let access, let security) = token.value else {
            return XCTFail("A certificate token hasn't been regenerated")
        }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(security.isEmpty)
        XCTAssertFalse(token.isExpired)
    }
}
