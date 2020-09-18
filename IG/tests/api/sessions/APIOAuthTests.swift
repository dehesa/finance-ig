@testable import IG
import ConbiniForTesting
import XCTest

/// Tests for the API OAuth endpoints.
final class APIOAuthTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Test the OAuth lifecycle: session creation, refresh, and disconnection.
    func testOAuth() {
        let api = API()
        XCTAssertEqual(api.session.status, .logout)
        
        // Log in through OAuth with the test account
        let credentials = api.session.loginOAuth(key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(credentials.client.description.isEmpty)
        XCTAssertFalse(credentials.token.isExpired)
        guard case .oauth(let access, let refresh, let scope, let type) = credentials.token.value else {
            return XCTFail("Credentials were expected to be OAuth. Credentials received: \(credentials)")
        }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(refresh.isEmpty)
        XCTAssertFalse(scope.isEmpty)
        XCTAssertFalse(type.isEmpty)
        // Generate a typical request header
        let headers = credentials.requestHeaders
        XCTAssertEqual(headers[.authorization], "\(type) \(access)")
        XCTAssertEqual(headers[.account], credentials.account.description)
        // Check the refresh operation work as intended.
        let token = api.session.refreshOAuth(token: refresh, key: credentials.key).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(token.isExpired)
        guard case .oauth(let newAccess, let newRefresh, let newScope, let newType) = token.value else {
            return XCTFail("The refresh operation didn't return an OAuth token")
        }
        XCTAssertNotEqual(access, newAccess)
        XCTAssertNotEqual(refresh, newRefresh)
        XCTAssertEqual(scope, newScope)
        XCTAssertEqual(type, newType)

        var newCredentials = credentials
        newCredentials.token = token
        api.channel.credentials = newCredentials
        
        api.session.logout().expectsCompletion(timeout: 1, on: self)
        XCTAssertNil(api.channel.credentials)
    }
}
