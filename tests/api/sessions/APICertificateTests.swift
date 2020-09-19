#if DEBUG
@testable import IG
import ConbiniForTesting
import XCTest

/// Tests for the API CST endpoints.
final class APICertificateTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the CST lifecycle: session creation, refresh, and disconnection.
    func testCertificateLogInOut() {
        let api = API()
        XCTAssertEqual(api.session.status, .logout)
        
        // Log in through certificate credentials with the test account
        let (credentials, _): (API.Credentials, API.Session.Settings) = api.session.loginCertificate(key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(credentials.client.description.isEmpty)
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
        let api = API()
        XCTAssertEqual(api.session.status, .logout)
        
        // Log in through certificate credentials with the test account
        let credentials = api.session.loginOAuth(key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsOne(timeout: 2, on: self)
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
#endif
