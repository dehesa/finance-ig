@testable import IG
import ReactiveSwift
import XCTest

/// Tests for the API CST endpoints.
final class APICertificateTests: XCTestCase {
    /// Tests the CST lifecycle: session creation, refresh, and disconnection.
    func testCertificateLogInOut() {
        let api = Test.makeAPI(credentials: nil)
        
        /// The info needed to request CST credentials.
        let info: (accountId: String, apiKey: String) = (Test.account.identifier, Test.account.api.key)
        guard case .user(let user) = Test.account.api.credentials else { return XCTFail("OAuth tests can't be performed without username and password.") }
        
        let credentials = try! api.session.loginCertificate(apiKey: info.apiKey, user: user).single()!.get()
        XCTAssertGreaterThan(credentials.clientIdentifier, 0)
        XCTAssertEqual(credentials.apiKey, info.apiKey)
        XCTAssertEqual(credentials.accountIdentifier, info.accountId)
        XCTAssertGreaterThan(credentials.token.expirationDate, Date())
        guard case .certificate(let access, let security) = credentials.token.value else {
            return XCTFail("Credentials were expected to be CST. Credentials received: \(credentials)")
        }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(security.isEmpty)

        let headers = credentials.requestHeaders
        XCTAssertEqual(headers[.clientSessionToken], access)
        XCTAssertEqual(headers[.securityToken], security)

        try! api.session.logout().single()!.get()
        XCTAssertNil(api.session.credentials)
    }
    
    /// Tests the refresh functionality.
    func testRefreshCertificates() {
        let api = Test.makeAPI(credentials: nil)
        
        let info: (accountId: String, apiKey: String) = (Test.account.identifier, Test.account.api.key)
        guard case .user(let user) = Test.account.api.credentials else { return XCTFail("OAuth tests can't be performed without username and password.") }
        
        let credentials = try! api.session.loginOAuth(apiKey: info.apiKey, user: user).single()!.get()
        api.session.credentials = credentials
        XCTAssertGreaterThan(credentials.clientIdentifier, 0)
        XCTAssertEqual(credentials.apiKey, info.apiKey)
        XCTAssertEqual(credentials.accountIdentifier, info.accountId)
        XCTAssertGreaterThan(credentials.token.expirationDate, Date())
        guard case .oauth = credentials.token.value else { return XCTFail("Credentials were expected to be OAuth. Credentials received: \(credentials)") }
        
        let token = try! api.session.refreshCertificate().single()!.get()
        XCTAssertGreaterThan(token.expirationDate, Date())
        guard case .certificate(let access, let security) = token.value else { return XCTFail("A certificate token hasn't been regenerated.") }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(security.isEmpty)
    }
}
