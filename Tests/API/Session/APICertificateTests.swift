@testable import IG
import ReactiveSwift
import XCTest

/// Tests for the API CST endpoints.
final class APICertificateTests: XCTestCase {
    /// Tests the CST lifecycle: session creation, refresh, and disconnection.
    func testCertificateLogInOut() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: nil, targetQueue: nil)
        let account = Test.account.identifier
        let key = Test.account.api.key
        guard case .user(let user) = Test.account.api.credentials else {
            return XCTFail("Certificate tests can't be performed without username and password.")
        }
        
        let returned = try! api.session.loginCertificate(key: key, user: user).single()!.get()
        XCTAssertNotNil(returned.settings)
        XCTAssertFalse(returned.credentials.client.rawValue.isEmpty)
        XCTAssertEqual(returned.credentials.key, key)
        XCTAssertEqual(returned.credentials.account, account)
        XCTAssertGreaterThan(returned.credentials.token.expirationDate, Date())
        guard case .certificate(let access, let security) = returned.credentials.token.value else {
            return XCTFail("Credentials were expected to be CST. Credentials received: \(returned.credentials)")
        }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(security.isEmpty)

        let headers = returned.credentials.requestHeaders
        XCTAssertEqual(headers[.clientSessionToken], access)
        XCTAssertEqual(headers[.securityToken], security)

        try! api.session.logout().single()!.get()
        XCTAssertNil(api.session.credentials)
    }
    
    /// Tests the refresh functionality.
    func testRefreshCertificates() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: nil, targetQueue: nil)
        let account = Test.account.identifier
        let key = Test.account.api.key
        guard case .user(let user) = Test.account.api.credentials else { return XCTFail("OAuth tests can't be performed without username and password.") }
        
        let credentials = try! api.session.loginOAuth(key: key, user: user).single()!.get()
        api.session.credentials = credentials
        XCTAssertFalse(credentials.client.rawValue.isEmpty)
        XCTAssertEqual(credentials.key, key)
        XCTAssertEqual(credentials.account, account)
        XCTAssertGreaterThan(credentials.token.expirationDate, Date())
        guard case .oauth = credentials.token.value else { return XCTFail("Credentials were expected to be OAuth. Credentials received: \(credentials)") }
        
        let token = try! api.session.refreshCertificate().single()!.get()
        XCTAssertGreaterThan(token.expirationDate, Date())
        guard case .certificate(let access, let security) = token.value else { return XCTFail("A certificate token hasn't been regenerated.") }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(security.isEmpty)
    }
}
